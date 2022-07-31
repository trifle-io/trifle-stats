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
          keys.map do |key|
            pkey = key.join(separator)

            _inc_all(key: pkey, data: self.class.pack(hash: values))
          end
        end

        def _inc_all(key:, data:)
          query = "INSERT INTO trifle_stats(key, data) VALUES ('#{key}', '#{data.to_json}') ON CONFLICT (key) DO UPDATE SET data = " + # rubocop:disable Layout/LineLength
                  data.inject('to_jsonb(trifle_stats.data)') { |o, (k, v)| "jsonb_set(#{o}, '{#{k}}', (COALESCE(trifle_stats.data->>'#{k}', '0')::int + #{v})::text::jsonb)" } # rubocop:disable Layout/LineLength

          client.exec(query)
        end

        def set(keys:, **values)
          keys.map do |key|
            pkey = key.join(separator)

            _set_all(key: pkey, data: self.class.pack(hash: values))
          end
        end

        def _set_all(key:, data:)
          query = "INSERT INTO trifle_stats(key, data) VALUES ('#{key}', '#{data.to_json}') ON CONFLICT (key) DO UPDATE SET data = " + # rubocop:disable Layout/LineLength
                  data.inject('to_jsonb(trifle_stats.data)') { |o, (k, v)| "jsonb_set(#{o}, '{#{k}}', (#{v})::text::jsonb)" } # rubocop:disable Layout/LineLength

          client.exec(query)
        end

        def get(keys:)
          pkeys = keys.map { |key| key.join(separator) }
          data = _get_all(keys: pkeys)
          map = data.inject({}) { |o, d| o.merge(d['key'] => d['data']) }

          pkeys.map { |pkey| self.class.unpack(hash: map[pkey]) || {} }
        end

        def _get_all(keys:)
          results = client.exec_params(
            "SELECT * FROM #{table_name} WHERE key IN ('#{keys.join("', '")}');"
          ).to_a

          results.map do |r|
            r['data'] = JSON.parse(r['data'])
            r
          rescue JSON::ParserError
            r
          end
        end
      end
    end
  end
end
