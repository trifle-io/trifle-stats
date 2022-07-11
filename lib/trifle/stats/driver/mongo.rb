# frozen_string_literal: true

require 'mongo'
require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Mongo
        include Mixins::Packer
        attr_accessor :client, :collection_name, :separator

        def initialize(client, collection_name: 'trifle_stats')
          @client = client
          @collection_name = collection_name
          @separator = '::'
        end

        def inc(keys:, **values)
          pkeys = keys.map { |key| key.join(separator) }

          collection.bulk_write(
            [upsert_operation('$inc', pkeys: pkeys, values: values)]
          )
        end

        def set(keys:, **values)
          pkeys = keys.map { |key| key.join(separator) }

          collection.bulk_write(
            [upsert_operation('$set', pkeys: pkeys, values: values)]
          )
        end

        def upsert_operation(operation, pkeys:, values:)
          data = self.class.pack(hash: { data: values })
          {
            update_many: {
              filter: { key: { '$in' => pkeys } },
              update: { operation => data },
              upsert: true
            }
          }
        end

        def get(keys:)
          pkeys = keys.map { |key| key.join(separator) }
          data = collection.find(key: { '$in' => pkeys })
          map = data.inject({}) { |o, d| o.merge(d['key'] => d['data']) }

          pkeys.map { |pkey| map[pkey] || {} }
        end

        private

        def collection
          client[collection_name]
        end
      end
    end
  end
end
