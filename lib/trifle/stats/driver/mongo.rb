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

        def inc(key:, **values)
          pkey = key.join(separator)

          collection.bulk_write(
            [upsert_operation('$inc', pkey: pkey, values: values)]
          )
        end

        def set(key:, **values)
          pkey = key.join(separator)

          collection.bulk_write(
            [upsert_operation('$set', pkey: pkey, values: values)]
          )
        end

        def upsert_operation(operation, pkey:, values:)
          data = self.class.pack(hash: { data: values })
          {
            update_many: {
              filter: { key: pkey },
              update: { operation => data },
              upsert: true
            }
          }
        end

        def get(key:)
          pkey = key.join(separator)

          data = collection.find(key: pkey).limit(1).first
          return {} if data.nil? || data['data'].nil?

          data['data']
        end

        private

        def collection
          client[collection_name]
        end
      end
    end
  end
end
