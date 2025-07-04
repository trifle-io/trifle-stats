# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Mongo
        include Mixins::Packer
        attr_accessor :client, :collection_name

        def initialize(client, collection_name: 'trifle_stats', joined_identifier: true, expire_after: nil)
          @client = client
          @collection_name = collection_name
          @joined_identifier = joined_identifier
          @expire_after = expire_after
          @separator = '::'
        end

        def self.setup!(client, collection_name: 'trifle_stats', joined_identifier: true)
          collection = client[collection_name]
          collection.create
          if joined_identifier
            collection.indexes.create_one({ key: 1 }, unique: true)
          else
            collection.indexes.create_one({ key: 1, range: 1, at: -1 }, unique: true)
            if expire_after
              collection.indexes.create_one({ at: 1 }, expire_after_seconds: expire_after)
            end
          end
        end

        def description
          "#{self.class.name}(#{@joined_identifier ? 'J' : 'S'})"
        end

        def separator
          @joined_identifier ? @separator : nil
        end

        def inc(keys:, **values)
          data = self.class.pack(hash: { data: values })

          collection.bulk_write(
            keys.map do |key|
              upsert_operation('$inc', filter: key.identifier(separator), data: data)
            end
          )
        end

        def set(keys:, **values)
          data = self.class.pack(hash: { data: values })

          collection.bulk_write(
            keys.map do |key|
              upsert_operation('$set', filter: key.identifier(separator), data: data)
            end
          )
        end

        def ping(key:, **values)
          data = self.class.pack(hash: { data: values, at: key.at })

          collection.bulk_write(
            [
              upsert_operation('$set', filter: key.identifier(separator).slice(:key), data: data)
            ]
          )
        end

        def upsert_operation(operation, filter:, data:)
          {
            update_many: {
              filter: filter,
              update: { operation => data },
              upsert: true
            }
          }
        end

        def get(keys:) # rubocop:disable Metrics/AbcSize
          combinations = keys.map { |key| key.identifier(separator) }
          data = collection.find('$or' => combinations)
          map = data.inject({}) do |o, d|
            o.merge(
              Nocturnal::Key.new(
                key: d['key'], range: d['range'], at: d['at']
              ).identifier(separator) => d['data']
            )
          end

          combinations.map { |combination| map[combination] || {} }
        end

        def scan(key:)
          return [] if @joined_identifier

          data = collection.find(
            **key.identifier(separator)
          ).sort(at: -1).first # rubocop:disable Style/RedundantSort
          return [] if data.nil?
          
          [data['at'], data['data']]
        end

        private

        def collection
          client[collection_name]
        end
      end
    end
  end
end
