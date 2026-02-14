# frozen_string_literal: true

require 'json'
require 'time'
require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Mysql # rubocop:disable Metrics/ClassLength
        include Mixins::Packer
        attr_accessor :client, :table_name, :ping_table_name

        def initialize(client, table_name: 'trifle_stats', joined_identifier: :full, ping_table_name: nil, system_tracking: true) # rubocop:disable Layout/LineLength
          @client = client
          @table_name = table_name
          @ping_table_name = ping_table_name || "#{table_name}_ping"
          @joined_identifier = self.class.normalize_joined_identifier(joined_identifier)
          @system_tracking = system_tracking
          @separator = '::'
        end

        def self.setup!(client, table_name: 'trifle_stats', joined_identifier: :full, ping_table_name: nil) # rubocop:disable Metrics/MethodLength
          ping_table_name ||= "#{table_name}_ping"
          identifier_mode = normalize_joined_identifier(joined_identifier)
          quoted_table_name = quote_identifier(table_name)
          quoted_ping_table_name = quote_identifier(ping_table_name)

          case identifier_mode
          when :full
            client.query(<<~SQL)
              CREATE TABLE IF NOT EXISTS #{quoted_table_name}
              (`key` VARCHAR(255) PRIMARY KEY, `data` JSON NOT NULL)
            SQL
          when :partial
            client.query(<<~SQL)
              CREATE TABLE IF NOT EXISTS #{quoted_table_name}
              (`key` VARCHAR(255) NOT NULL, `at` DATETIME(6) NOT NULL, `data` JSON NOT NULL, PRIMARY KEY (`key`, `at`))
            SQL
          else
            client.query(<<~SQL)
              CREATE TABLE IF NOT EXISTS #{quoted_table_name}
              (`key` VARCHAR(255) NOT NULL, `granularity` VARCHAR(255) NOT NULL, `at` DATETIME(6) NOT NULL, `data` JSON NOT NULL, PRIMARY KEY (`key`, `granularity`, `at`))
            SQL
            client.query(<<~SQL)
              CREATE TABLE IF NOT EXISTS #{quoted_ping_table_name}
              (`key` VARCHAR(255) PRIMARY KEY, `at` DATETIME(6) NOT NULL, `data` JSON NOT NULL)
            SQL
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
          with_transaction(client) do |connection|
            keys.each do |key|
              identifier = identifier_for(key)
              query, args = inc_query(identifier: identifier, data: data)
              execute_prepared(connection, query, args)
              track_system_data(connection, key, count, tracking_key)
            end
          end
        end

        def set(keys:, values:, count: 1, tracking_key: nil)
          data = self.class.pack(hash: values)
          with_transaction(client) do |connection|
            keys.each do |key|
              identifier = identifier_for(key)
              query, args = set_query(identifier: identifier, data: data)
              execute_prepared(connection, query, args)
              track_system_data(connection, key, count, tracking_key)
            end
          end
        end

        def get(keys:)
          keys.map do |key|
            identifier = identifier_for(key)
            self.class.unpack(hash: fetch_packed_data(identifier))
          end
        end

        def ping(key:, values:)
          return [] if @joined_identifier

          data = self.class.pack(hash: { data: values, at: key.at })
          query, args = ping_query(key: key.key, at: key.at, data: data)

          with_transaction(client) do |connection|
            execute_prepared(connection, query, args)
          end
        end

        # rubocop:disable Metrics/MethodLength
        def scan(key:)
          return [] if @joined_identifier

          query = <<~SQL
            SELECT `at`, CAST(`data` AS CHAR) AS data
            FROM #{self.class.quote_identifier(ping_table_name)}
            WHERE `key` = ?
            ORDER BY `at` DESC
            LIMIT 1
          SQL
          result = execute_prepared(client, query, [key.key]).first
          return [] if result.nil?

          [parse_time_value(result['at']), self.class.unpack(hash: JSON.parse(result['data']))]
        rescue JSON::ParserError
          []
        end
        # rubocop:enable Metrics/MethodLength

        def self.normalize_joined_identifier(value)
          case value
          when nil, :full, 'full', :partial, 'partial'
            value.nil? ? nil : value.to_sym
          else
            raise ArgumentError, 'joined_identifier must be nil, :full, "full", :partial, or "partial"'
          end
        end

        def self.quote_identifier(identifier)
          "`#{identifier.to_s.gsub('`', '``')}`"
        end

        private

        def track_system_data(connection, key, count, tracking_key)
          return unless @system_tracking

          query, args = inc_query(
            identifier: system_identifier_for(key: key),
            data: system_data_for(key: key, count: count, tracking_key: tracking_key)
          )
          execute_prepared(connection, query, args)
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def fetch_packed_data(identifier)
          conditions = identifier.keys.map { |column| "#{self.class.quote_identifier(column)} = ?" }.join(' AND ')
          query = <<~SQL
            SELECT CAST(`data` AS CHAR) AS data
            FROM #{self.class.quote_identifier(table_name)}
            WHERE #{conditions}
            LIMIT 1
          SQL
          packed_data = execute_prepared(client, query, query_values(identifier)).first&.fetch('data', nil)
          return {} if packed_data.nil? || packed_data.empty?

          JSON.parse(packed_data)
        rescue JSON::ParserError
          {}
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def inc_query(identifier:, data:)
          upsert_query(
            identifier: identifier,
            data: data,
            conflict_data_sql: build_inc_json_set_expression(data),
            conflict_values: increment_values(data)
          )
        end

        def set_query(identifier:, data:)
          upsert_query(
            identifier: identifier,
            data: data,
            conflict_data_sql: build_set_json_set_expression(data),
            conflict_values: serialized_set_values(data)
          )
        end

        def upsert_query(identifier:, data:, conflict_data_sql:, conflict_values:)
          columns = identifier.keys
          columns_sql = columns.map { |column| self.class.quote_identifier(column) }.join(', ')
          values_sql = (['?'] * columns.size + ['CAST(? AS JSON)']).join(', ')

          query = <<~SQL
            INSERT INTO #{self.class.quote_identifier(table_name)} (#{columns_sql}, `data`) VALUES (#{values_sql})
            ON DUPLICATE KEY UPDATE `data` = #{conflict_data_sql}
          SQL

          [query, query_values(identifier) + [JSON.generate(data)] + conflict_values]
        end

        def ping_query(key:, at:, data:)
          query = <<~SQL
            INSERT INTO #{self.class.quote_identifier(ping_table_name)} (`key`, `at`, `data`) VALUES (?, ?, CAST(? AS JSON))
            ON DUPLICATE KEY UPDATE `at` = VALUES(`at`), `data` = VALUES(`data`)
          SQL
          [query, [key.to_s, format_time_value(at), JSON.generate(data)]]
        end

        def build_inc_json_set_expression(data)
          expression = +'JSON_SET(COALESCE(`data`, JSON_OBJECT())'
          data.each_key do |path_key|
            path = json_path_for(path_key)
            expression << ", '#{path}', (COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(COALESCE(`data`, JSON_OBJECT()), '#{path}')) AS DECIMAL(65,10)), 0) + CAST(? AS DECIMAL(65,10)))" # rubocop:disable Layout/LineLength
          end
          expression << ')'
          expression
        end

        def build_set_json_set_expression(data)
          expression = +'JSON_SET(COALESCE(`data`, JSON_OBJECT())'
          data.each_key do |path_key|
            path = json_path_for(path_key)
            expression << ", '#{path}', CAST(? AS JSON)"
          end
          expression << ')'
          expression
        end

        def query_values(identifier)
          identifier.values.map { |value| normalize_query_value(value) }
        end

        def increment_values(data)
          data.map do |key, value|
            next value if value.is_a?(Numeric)

            raise ArgumentError, "increment requires numeric value for key #{key.inspect}"
          end
        end

        def serialized_set_values(data)
          data.values.map { |value| JSON.generate(value) }
        end

        def normalize_query_value(value)
          return format_time_value(value) if value.is_a?(Time)

          value
        end

        def format_time_value(value)
          parse_time_value(value).utc.strftime('%Y-%m-%d %H:%M:%S.%6N')
        end

        def parse_time_value(value)
          case value
          when Time
            value
          when String
            Time.parse(value)
          when DateTime
            value.to_time
          else
            raise ArgumentError, "unsupported time value: #{value.inspect}"
          end
        end

        def json_path_for(key)
          escaped = key.to_s.gsub('\\', '\\\\').gsub('"', '\"').gsub("'", "''")
          "$.\"#{escaped}\""
        end

        def with_transaction(connection)
          connection.query('START TRANSACTION')
          result = yield(connection)
          connection.query('COMMIT')
          result
        rescue StandardError
          connection.query('ROLLBACK')
          raise
        end

        def execute_prepared(connection, query, args = [])
          statement = connection.prepare(query)
          result = statement.execute(*args)
          result.respond_to?(:to_a) ? result.to_a : result
        ensure
          statement&.close
        end

        def identifier_for(key)
          key.identifier(separator, @joined_identifier)
        end
      end
    end
  end
end
