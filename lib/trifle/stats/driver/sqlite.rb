# frozen_string_literal: true

require 'json'
require 'time'
require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Sqlite # rubocop:disable Metrics/ClassLength
        include Mixins::Packer
        attr_accessor :client, :table_name, :ping_table_name

        def initialize(client = SQLite3::Database.new('stats.db'), table_name: 'trifle_stats', joined_identifier: :full, ping_table_name: nil, system_tracking: true) # rubocop:disable Layout/LineLength
          @client = client
          @table_name = table_name
          @ping_table_name = ping_table_name || "#{table_name}_ping"
          @joined_identifier = self.class.normalize_joined_identifier(joined_identifier)
          @system_tracking = system_tracking
          @separator = '::'
        end

        def self.setup!(client = SQLite3::Database.new('stats.db'), table_name: 'trifle_stats', joined_identifier: :full, ping_table_name: nil) # rubocop:disable Layout/LineLength, Metrics/MethodLength
          ping_table_name ||= "#{table_name}_ping"
          identifier_mode = normalize_joined_identifier(joined_identifier)

          case identifier_mode
          when :full
            client.execute("CREATE TABLE #{table_name} (key varchar(255), data json);")
            client.execute("CREATE UNIQUE INDEX idx_#{table_name}_key ON #{table_name} (key);")
          when :partial
            client.execute("CREATE TABLE #{table_name} (key varchar(255) NOT NULL, at datetime NOT NULL, data json, PRIMARY KEY (key, at));") # rubocop:disable Layout/LineLength
          else
            client.execute("CREATE TABLE #{table_name} (key varchar(255) NOT NULL, granularity varchar(255) NOT NULL, at datetime NOT NULL, data json, PRIMARY KEY (key, granularity, at));") # rubocop:disable Layout/LineLength

            # Create ping table for separated mode only
            client.execute("CREATE TABLE #{ping_table_name} (key varchar(255) PRIMARY KEY, at datetime NOT NULL, data json);") # rubocop:disable Layout/LineLength
          end
        end

        def description
          mode = if @joined_identifier == :full
                   'J'
                 else
                   @joined_identifier == :partial ? 'P' : 'S'
                 end
          "#{self.class.name}(#{mode})"
        end

        attr_reader :separator

        def system_identifier_for(key:)
          key = Nocturnal::Key.new(key: '__system__key__', granularity: key.granularity, at: key.at)
          identifier_for(key)
        end

        def system_data_for(key:, count: 1, tracking_key: nil)
          tracking_key ||= key.key
          self.class.pack(hash: { count: count, keys: { tracking_key => count } })
        end

        def inc(keys:, values:, count: 1, tracking_key: nil)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.each do |key|
              identifier = identifier_for(key)
              batch_data_operations(identifier: identifier, data: data, connection: c, operation: :inc)
              track_system_data(c, key, count, tracking_key)
            end
          end
        end

        def inc_query(identifier:, data:) # rubocop:disable Metrics/MethodLength
          columns = identifier.keys.join(', ')
          placeholders = (['?'] * identifier.size).join(', ')
          expression = data.inject('data') do |o, (k, v)|
            path = json_path_for(k)
            "json_set(#{o}, '#{path}', IFNULL(json_extract(data, '#{path}'), 0) + #{numeric_value(k, v)})"
          end

          query = <<-SQL
            INSERT INTO #{table_name} (#{columns}, data) VALUES (#{placeholders}, json(?))
            ON CONFLICT (#{columns}) DO UPDATE SET data = #{expression};
          SQL
          [query, query_params(identifier) + [data.to_json]]
        end

        def set(keys:, values:, count: 1, tracking_key: nil)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.each do |key|
              identifier = identifier_for(key)
              batch_data_operations(identifier: identifier, data: data, connection: c, operation: :set)
              track_system_data(c, key, count, tracking_key)
            end
          end
        end

        def track_system_data(connection, key, count, tracking_key)
          return unless @system_tracking

          batch_data_operations(
            identifier: system_identifier_for(key: key),
            data: system_data_for(key: key, count: count, tracking_key: tracking_key),
            connection: connection,
            operation: :inc
          )
        end

        def set_query(identifier:, data:) # rubocop:disable Metrics/MethodLength
          columns = identifier.keys.join(', ')
          placeholders = (['?'] * identifier.size).join(', ')
          params = query_params(identifier) + [data.to_json]
          expression = data.inject('data') do |o, (k, v)|
            params << v.to_json
            "json_set(#{o}, '#{json_path_for(k)}', json(?))"
          end

          query = <<-SQL
            INSERT INTO #{table_name} (#{columns}, data) VALUES (#{placeholders}, json(?))
            ON CONFLICT (#{columns}) DO UPDATE SET data = #{expression};
          SQL
          [query, params]
        end

        def get(keys:)
          identifiers = keys.map { |key| identifier_for(key) }
          data = get_all(identifiers: identifiers)
          identifiers.map { |identifier| self.class.unpack(hash: data.fetch(identifier, {})) }
        end

        def get_all(identifiers:) # rubocop:disable Metrics/AbcSize
          query, params = get_query(identifiers: identifiers)
          results = client.execute(query, params).to_a
          sample = identifiers.first

          results.each_with_object(Hash.new({})) do |r, o|
            identifier = sample.each_with_index.to_h { |(k, _), i| [k, k == :at ? Time.iso8601(r[i]) : r[i]] }

            o[identifier] = JSON.parse(r.last)
          rescue JSON::ParserError
            nil
          end
        end

        def get_query(identifiers:)
          params = []
          conditions = identifiers.map do |identifier|
            identifier.map { |k, v| build_field_condition(k, v, params) }.join(' AND ')
          end.join(' OR ')

          query = <<-SQL
            SELECT * FROM #{table_name} WHERE #{conditions};
          SQL
          [query, params]
        end

        def ping(key:, values:)
          return [] if @joined_identifier

          data = self.class.pack(hash: { data: values, at: key.at })
          query, params = ping_query(key: key.key, at: key.at, data: data)
          client.transaction do |c|
            c.execute(query, params) # TODO: should use batch_data_operations
          end
        end

        def ping_query(key:, at:, data:)
          at_formatted = format_time_value(at)

          query = <<-SQL
            INSERT INTO #{ping_table_name} (key, at, data) VALUES (?, ?, json(?))
            ON CONFLICT (key) DO UPDATE SET at = ?, data = json(?);
          SQL
          [query, [key.to_s, at_formatted, data.to_json, at_formatted, data.to_json]]
        end

        def scan(key:)
          return [] if @joined_identifier

          query, params = scan_query(key: key.key)
          result = client.execute(query, params).first
          return [] if result.nil?

          # SQLite returns columns in order: key, at, data
          [Time.iso8601(result[1]), self.class.unpack(hash: JSON.parse(result[2]))]
        rescue JSON::ParserError
          []
        end

        def scan_query(key:)
          query = <<-SQL
            SELECT key, at, data FROM #{ping_table_name} WHERE key = ? ORDER BY at DESC LIMIT 1;
          SQL
          [query, [key.to_s]]
        end

        def self.normalize_joined_identifier(value)
          case value
          when nil, :full, 'full', :partial, 'partial'
            value.nil? ? nil : value.to_sym
          else
            raise ArgumentError, 'joined_identifier must be nil, :full, "full", :partial, or "partial"'
          end
        end

        private

        def build_field_condition(key, value, params)
          unless key == :at
            params << query_param(value)
            return "#{key} = ?"
          end

          formatted = format_time_value(value)
          params << formatted
          params << formatted.sub('Z', '.000000Z')

          '(at = ? OR at = ?)'
        end

        # Batch data operations to avoid SQLite parser stack overflow
        # Splits large data hashes into smaller chunks to prevent too many nested json_set calls
        def batch_data_operations(identifier:, data:, connection:, operation:)
          # SQLite can handle about 10-15 nested json_set calls safely
          batch_size = 10
          data.each_slice(batch_size) do |batch|
            batch_data = batch.to_h
            query, params = send("#{operation}_query", identifier: identifier, data: batch_data)
            connection.execute(query, params)
          end
        end

        def query_params(identifier)
          identifier.values.map { |value| query_param(value) }
        end

        def query_param(value)
          return format_time_value(value) if value.is_a?(Time) || value.is_a?(DateTime)
          return value if value.is_a?(Integer) || value.is_a?(Float)

          value.to_s
        end

        def numeric_value(key, value)
          return value.to_s if value.is_a?(Numeric)

          raise ArgumentError, "increment requires numeric value for key #{key.inspect}"
        end

        def json_path_for(key)
          "$.#{key.to_s.gsub("'", "''")}"
        end

        def format_time_value(value)
          case value
          when Time
            value.getutc.iso8601(0)
          when DateTime
            value.to_time.getutc.iso8601(0)
          when Integer
            Time.at(value).getutc.iso8601(0)
          else
            Time.iso8601(value.to_s).getutc.iso8601(0)
          end
        end

        def build_map_key(data)
          return data[:key] if @joined_identifier == :full
          return "#{data[:key]}::#{data[:at]}" if @joined_identifier == :partial

          "#{data[:key]}::#{data[:granularity]}::#{data[:at]}"
        end

        def build_identifier_key(identifier)
          return identifier[:key] if @joined_identifier == :full
          return "#{identifier[:key]}::#{format_time_value(identifier[:at])}" if @joined_identifier == :partial

          "#{identifier[:key]}::#{identifier[:granularity]}::#{format_time_value(identifier[:at])}"
        end

        def identifier_for(key)
          key.identifier(separator, @joined_identifier)
        end
      end
    end
  end
end
