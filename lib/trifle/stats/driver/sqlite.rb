# frozen_string_literal: true

require 'json'
require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Sqlite # rubocop:disable Metrics/ClassLength
        include Mixins::Packer
        attr_accessor :client, :table_name, :ping_table_name

        def separator
          @joined_identifier ? @separator : nil
        end

        def initialize(client = SQLite3::Database.new('stats.db'), table_name: 'trifle_stats', joined_identifier: true, ping_table_name: nil) # rubocop:disable Layout/LineLength
          @client = client
          @table_name = table_name
          @ping_table_name = ping_table_name || "#{table_name}_ping"
          @joined_identifier = joined_identifier
          @separator = '::'
        end

        def self.setup!(client = SQLite3::Database.new('stats.db'), table_name: 'trifle_stats', joined_identifier: true, ping_table_name: nil) # rubocop:disable Layout/LineLength
          ping_table_name ||= "#{table_name}_ping"

          if joined_identifier
            client.execute("CREATE TABLE #{table_name} (key varchar(255), data json);")
            client.execute("CREATE UNIQUE INDEX idx_#{table_name}_key ON #{table_name} (key);")
          else
            client.execute("CREATE TABLE #{table_name} (key varchar(255) NOT NULL, granularity varchar(255) NOT NULL, at datetime NOT NULL, data json, PRIMARY KEY (key, granularity, at));") # rubocop:disable Layout/LineLength

            # Create ping table for separated mode only
            client.execute("CREATE TABLE #{ping_table_name} (key varchar(255) PRIMARY KEY, at datetime NOT NULL, data json);") # rubocop:disable Layout/LineLength
          end
        end

        def description
          "#{self.class.name}(#{@joined_identifier ? 'J' : 'S'})"
        end

        def inc(keys:, values:)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.each do |key|
              identifier = key.identifier(separator)
              # Batch data operations to avoid SQLite parser stack overflow
              batch_data_operations(identifier: identifier, data: data, connection: c, operation: :inc)
            end
          end
        end

        def inc_query(identifier:, data:)
          columns = identifier.keys.join(', ')
          values = identifier.values.map { |v| format_value(v) }.join(', ')
          conflict_columns = identifier.keys.join(', ')

          <<-SQL
            INSERT INTO #{table_name} (#{columns}, data) VALUES (#{values}, json('#{data.to_json}'))
            ON CONFLICT (#{conflict_columns}) DO UPDATE SET data =
            #{data.inject('data') { |o, (k, v)| "json_set(#{o}, '$.#{k}', IFNULL(json_extract(data, '$.#{k}'), 0) + #{v})" }};
          SQL
        end

        def set(keys:, values:)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.each do |key|
              identifier = key.identifier(separator)
              # Batch data operations to avoid SQLite parser stack overflow
              batch_data_operations(identifier: identifier, data: data, connection: c, operation: :set)
            end
          end
        end

        def set_query(identifier:, data:)
          columns = identifier.keys.join(', ')
          values = identifier.values.map { |v| format_value(v) }.join(', ')
          conflict_columns = identifier.keys.join(', ')

          <<-SQL
            INSERT INTO #{table_name} (#{columns}, data) VALUES (#{values}, json('#{data.to_json}'))
            ON CONFLICT (#{conflict_columns}) DO UPDATE SET data =
            #{data.inject('data') { |o, (k, v)| "json_set(#{o}, '$.#{k}', #{v.to_json})" }};
          SQL
        end

        def get(keys:)
          identifiers = keys.map { |key| key.identifier(separator) }
          data = get_all(identifiers: identifiers)
          identifiers.map { |identifier| self.class.unpack(hash: data.fetch(identifier, {})) }
        end

        def get_all(identifiers:) # rubocop:disable Metrics/AbcSize
          results = client.execute(get_query(identifiers: identifiers)).to_a
          sample = identifiers.first

          results.each_with_object(Hash.new({})) do |r, o|
            identifier = sample.each_with_index.to_h { |(k, _), i| [k, k == :at ? Time.parse(r[i]) : r[i]] }

            o[identifier] = JSON.parse(r.last)
          rescue JSON::ParserError
            nil
          end
        end

        def get_query(identifiers:)
          conditions = identifiers.map do |identifier|
            identifier.map { |k, v| "#{k} = #{format_value(v)}" }.join(' AND ')
          end.join(' OR ')

          <<-SQL
            SELECT * FROM #{table_name} WHERE #{conditions};
          SQL
        end

        def ping(key:, values:)
          return [] if @joined_identifier

          data = self.class.pack(hash: { data: values, at: key.at })
          operation = ping_query(key: key.key, at: key.at, data: data)
          client.transaction { |c| c.execute(operation) }
        end

        def ping_query(key:, at:, data:)
          <<-SQL
            INSERT INTO #{ping_table_name} (key, at, data) VALUES ('#{key}', '#{at.strftime('%Y-%m-%d %H:%M:%S')}', json('#{data.to_json}'))
            ON CONFLICT (key) DO UPDATE SET at = '#{at.strftime('%Y-%m-%d %H:%M:%S')}', data = json('#{data.to_json}');
          SQL
        end

        def scan(key:)
          return [] if @joined_identifier

          result = client.execute(scan_query(key: key.key)).first
          return [] if result.nil?

          # SQLite returns columns in order: key, at, data
          [Time.parse(result[1]), self.class.unpack(hash: JSON.parse(result[2]))]
        rescue JSON::ParserError
          []
        end

        def scan_query(key:)
          <<-SQL
            SELECT key, at, data FROM #{ping_table_name} WHERE key = '#{key}' ORDER BY at DESC LIMIT 1;
          SQL
        end

        private

        # Batch data operations to avoid SQLite parser stack overflow
        # Splits large data hashes into smaller chunks to prevent too many nested json_set calls
        def batch_data_operations(identifier:, data:, connection:, operation:)
          # SQLite can handle about 10-15 nested json_set calls safely
          batch_size = 10
          data.each_slice(batch_size) do |batch|
            batch_data = batch.to_h
            query = send("#{operation}_query", identifier: identifier, data: batch_data)
            connection.execute(query)
          end
        end

        def format_value(value)
          case value
          when String
            "'#{value}'"
          when Time
            "'#{value.strftime('%Y-%m-%d %H:%M:%S')}'"
          when Integer, Float
            value.to_s
          else
            "'#{value}'"
          end
        end

        def build_map_key(data)
          @joined_identifier ? data[:key] : "#{data[:key]}::#{data[:granularity]}::#{data[:at]}"
        end

        def build_identifier_key(identifier)
          @joined_identifier ? identifier[:key] : "#{identifier[:key]}::#{identifier[:granularity]}::#{identifier[:at].strftime('%Y-%m-%d %H:%M:%S')}" # rubocop:disable Layout/LineLength
        end
      end
    end
  end
end
