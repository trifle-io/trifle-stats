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

            self.class.pack(hash: values).each do |k, c|
              _inc_one(key: pkey, name: k, value: c)
            end
          end
        end

        def _inc_one(key:, name:, value:)
          data = { name => value }
          query = "INSERT INTO trifle_stats(key, data) VALUES ('#{key}', '#{data.to_json}') ON CONFLICT (key) DO UPDATE SET data = jsonb_set(to_jsonb(trifle_stats.data), '{#{name}}', (COALESCE(trifle_stats.data->>'#{name}','0')::int + #{value})::text::jsonb)" # rubocop:disable Metric/LineLength

          client.exec(query)
        end

        def set(keys:, **values)
          keys.map do |key|
            pkey = key.join(separator)

            _set_all(key: pkey, **values)
          end
        end

        def _set_all(key:, **values)
          data = self.class.pack(hash: values)
          query = "INSERT INTO trifle_stats(key, data) VALUES ('#{key}', '#{data.to_json}') ON CONFLICT (key) DO UPDATE SET data = '#{data.to_json}'" # rubocop:disable Metric/LineLength

          client.exec(query)
        end

        def get(keys:)
          keys.map do |key|
            pkey = key.join(separator)

            data = _get(key: pkey)
            return {} if data.nil?

            self.class.unpack(hash: data)
          end
        end

        def _get(key:)
          result = client.exec_params(
            "SELECT * FROM #{table_name} WHERE key = $1 LIMIT 1;", [key]
          ).to_a.first
          return nil if result.nil?

          JSON.parse(result.try(:fetch, 'data'))
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
