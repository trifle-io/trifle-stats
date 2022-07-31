# frozen_string_literal: true

require 'pg'
require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Postgres
        include Mixins::Packer
        attr_accessor :client, :table_name, :separator

        def initialize(client = PG::Connection.new, table_name: 'trifle_stats')
          @client = client
          @table_name = table_name
          @separator = '::'
        end

        def inc(keys:, **values)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.map do |key|
              pkey = key.join(separator)
              c.exec(inc_query(key: pkey, data: data))
            end
          end
        end

        def inc_query(key:, data:)
          <<-SQL
            INSERT INTO #{table_name} (key, data) VALUES ('#{key}', '#{data.to_json}')
            ON CONFLICT (key) DO UPDATE SET data =
            #{data.inject("to_jsonb(#{table_name}.data)") { |o, (k, v)| "jsonb_set(#{o}, '{#{k}}', (COALESCE(trifle_stats.data->>'#{k}', '0')::int + #{v})::text::jsonb)" }};
          SQL
        end

        def set(keys:, **values)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.map do |key|
              pkey = key.join(separator)
              c.exec(set_query(key: pkey, data: data))
            end
          end
        end

        def set_query(key:, data:)
          <<-SQL
            INSERT INTO #{table_name} (key, data) VALUES ('#{key}', '#{data.to_json}')
            ON CONFLICT (key) DO UPDATE SET data =
            #{data.inject("to_jsonb(#{table_name}.data)") { |o, (k, v)| "jsonb_set(#{o}, '{#{k}}', (#{v})::text::jsonb)" }}
          SQL
        end

        def get(keys:)
          pkeys = keys.map { |key| key.join(separator) }
          data = get_all(keys: pkeys)
          map = data.inject({}) { |o, d| o.merge(d[:key] => d[:data]) }

          pkeys.map { |pkey| self.class.unpack(hash: map.fetch(pkey, {})) }
        end

        def get_all(keys:)
          results = client.exec_params(get_query(keys: keys)).to_a

          results.map do |r|
            r['data'] = JSON.parse(r['data'])
            { key: r['key'], data: JSON.parse(r['data']) }
          rescue JSON::ParserError
            { key: r['key'], data: {} }
          end
        end

        def get_query(keys:)
          <<-SQL
            SELECT * FROM #{table_name} WHERE key IN ('#{keys.join("', '")}');
          SQL
        end
      end
    end
  end
end
