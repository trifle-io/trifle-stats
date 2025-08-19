# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Postgres # rubocop:disable Metrics/ClassLength
        include Mixins::Packer
        attr_accessor :client, :table_name, :ping_table_name

        def separator
          @joined_identifier ? @separator : nil
        end

        def initialize(client = PG::Connection.new, table_name: 'trifle_stats', joined_identifier: true, ping_table_name: nil) # rubocop:disable Layout/LineLength
          @client = client
          @table_name = table_name
          @ping_table_name = ping_table_name || "#{table_name}_ping"
          @joined_identifier = joined_identifier
          @separator = '::'
        end

        def self.setup!(client = PG::Connection.new, table_name: 'trifle_stats', joined_identifier: true, ping_table_name: nil) # rubocop:disable Layout/LineLength
          ping_table_name ||= "#{table_name}_ping"

          if joined_identifier
            client.exec("CREATE TABLE #{table_name} (key VARCHAR(255) PRIMARY KEY, data JSONB NOT NULL DEFAULT '{}'::jsonb)") # rubocop:disable Layout/LineLength
          else
            client.exec("CREATE TABLE #{table_name} (key VARCHAR(255) NOT NULL, granularity VARCHAR(255) NOT NULL, at TIMESTAMPTZ NOT NULL, data JSONB NOT NULL DEFAULT '{}'::jsonb, PRIMARY KEY (key, granularity, at))") # rubocop:disable Layout/LineLength

            # Create ping table for separated mode only
            client.exec("CREATE TABLE #{ping_table_name} (key VARCHAR(255) PRIMARY KEY, at TIMESTAMPTZ NOT NULL, data JSONB NOT NULL DEFAULT '{}'::jsonb)") # rubocop:disable Layout/LineLength
          end
        end

        def description
          "#{self.class.name}(#{@joined_identifier ? 'J' : 'S'})"
        end

        def inc(keys:, **values)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.map do |key|
              identifier = key.identifier(separator)
              c.exec(inc_query(identifier: identifier, data: data))
            end
          end
        end

        def inc_query(identifier:, data:)
          columns = identifier.keys.join(', ')
          values = identifier.values.map { |v| format_value(v) }.join(', ')
          conflict_columns = identifier.keys.join(', ')

          <<-SQL
            INSERT INTO #{table_name} (#{columns}, data) VALUES (#{values}, '#{data.to_json}')
            ON CONFLICT (#{conflict_columns}) DO UPDATE SET data =
            #{data.inject("to_jsonb(#{table_name}.data)") { |o, (k, v)| "jsonb_set(#{o}, '{#{k}}', (COALESCE(#{table_name}.data->>'#{k}', '0')::int + #{v})::text::jsonb)" }};
          SQL
        end

        def set(keys:, **values)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.map do |key|
              identifier = key.identifier(separator)
              c.exec(set_query(identifier: identifier, data: data))
            end
          end
        end

        def set_query(identifier:, data:)
          columns = identifier.keys.join(', ')
          values = identifier.values.map { |v| format_value(v) }.join(', ')
          conflict_columns = identifier.keys.join(', ')

          <<-SQL
            INSERT INTO #{table_name} (#{columns}, data) VALUES (#{values}, '#{data.to_json}')
            ON CONFLICT (#{conflict_columns}) DO UPDATE SET data =
            #{data.inject("to_jsonb(#{table_name}.data)") { |o, (k, v)| "jsonb_set(#{o}, '{#{k}}', '#{v.to_json}'::jsonb)" }}
          SQL
        end

        def get(keys:)
          identifiers = keys.map { |key| key.identifier(separator) }
          data = get_all(identifiers: identifiers)
          identifiers.map { |identifier| self.class.unpack(hash: data.fetch(identifier, {})) }
        end

        def get_all(identifiers:) # rubocop:disable Metrics/AbcSize
          results = client.exec_params(get_query(identifiers: identifiers)).to_a
          sample = identifiers.first

          results.each_with_object(Hash.new({})) do |r, o|
            identifier = sample.to_h { |k, _| [k, k == :at ? Time.parse(r[k.to_s]) : r[k.to_s]] }

            o[identifier] = JSON.parse(r['data'])
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

        def ping(key:, **values)
          return [] if @joined_identifier

          data = self.class.pack(hash: { data: values, at: key.at })
          operation = ping_query(key: key.key, at: key.at, data: data)
          client.transaction { |c| c.exec(operation) }
        end

        def ping_query(key:, at:, data:)
          <<-SQL
            INSERT INTO #{ping_table_name} (key, at, data) VALUES ('#{key}', '#{at.iso8601}', '#{data.to_json}')
            ON CONFLICT (key) DO UPDATE SET at = '#{at.iso8601}', data = '#{data.to_json}'::jsonb;
          SQL
        end

        def scan(key:)
          return [] if @joined_identifier

          result = client.exec_params(scan_query(key: key.key)).to_a.first
          return [] if result.nil?

          [Time.parse(result['at']), self.class.unpack(hash: JSON.parse(result['data']))]
        rescue JSON::ParserError
          []
        end

        def scan_query(key:)
          <<-SQL
            SELECT at, data FROM #{ping_table_name} WHERE key = '#{key}' ORDER BY at DESC LIMIT 1;
          SQL
        end

        private

        def format_value(value)
          case value
          when String
            "'#{value}'"
          when Time
            "'#{value.utc.strftime('%Y-%m-%d %H:%M:%S+00')}'"
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
          @joined_identifier ? identifier[:key] : "#{identifier[:key]}::#{identifier[:granularity]}::#{identifier[:at].utc.strftime('%Y-%m-%d %H:%M:%S+00')}" # rubocop:disable Layout/LineLength
        end
      end
    end
  end
end
