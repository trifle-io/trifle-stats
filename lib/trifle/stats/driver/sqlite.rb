# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Sqlite
        include Mixins::Packer
        attr_accessor :client, :table_name, :separator

        def initialize(client = SQLite3::Database.new('stats.db'), table_name: 'trifle_stats')
          @client = client
          @table_name = table_name
          @separator = '::'
        end

        def self.setup!(client = SQLite3::Database.new('stats.db'), table_name: 'trifle_stats')
          client.execute("CREATE TABLE #{table_name} (key varchar(255), data json);")
          client.execute("CREATE UNIQUE INDEX idx_#{table_name}_key ON #{table_name} (key);")
        end

        def description
          "#{self.class.name}(J)"
        end

        def inc(keys:, **values)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.each do |key|
              pkey = key.join(separator)
              c.execute(inc_query(key: pkey, data: data))
            end
          end
        end

        def inc_query(key:, data:)
          <<-SQL
            INSERT INTO #{table_name} (key, data) values('#{key}', json('#{data.to_json}'))
            ON CONFLICT (key) DO UPDATE SET data =
            #{data.inject('data') { |o, (k, v)| "json_set(#{o}, '$.#{k}', IFNULL(json_extract(data, '$.#{k}'), 0) + #{v})" }};
          SQL
        end

        def set(keys:, **values)
          data = self.class.pack(hash: values)
          client.transaction do |c|
            keys.each do |key|
              pkey = key.join(separator)
              c.execute(set_query(key: pkey, data: data))
            end
          end
        end

        def set_query(key:, data:)
          <<-SQL
            INSERT INTO #{table_name} (key, data) values('#{key}', json('#{data.to_json}'))
            ON CONFLICT (key) DO UPDATE SET data =
            #{data.inject('data') { |o, (k, v)| "json_set(#{o}, '$.#{k}', #{v})" }};
          SQL
        end

        def get(keys:)
          pkeys = keys.map { |key| key.join(separator) }
          data = get_all(keys: pkeys)
          map = data.inject({}) { |o, d| o.merge(d[:key] => d[:data]) }

          pkeys.map { |pkey| map.fetch(pkey, {}) }
        end

        def get_all(keys:)
          results = client.execute(get_query(keys: keys)).to_a

          results.map do |key, data|
            { key: key, data: JSON.parse(data) }
          rescue JSON::ParserError
            { key: key, data: {} }
          end
        end

        def get_query(keys:)
          <<-SQL
            SELECT key, data FROM #{table_name} WHERE key IN ('#{keys.join("', '")}');
          SQL
        end

        def ping(*)
          []
        end

        def scan(*)
          []
        end
      end
    end
  end
end
