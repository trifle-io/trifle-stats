# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Redis
        include Mixins::Packer
        attr_accessor :client, :prefix, :separator

        def initialize(client, prefix: 'trfl')
          @client = client
          @prefix = prefix
          @separator = '::'
        end

        def inc(keys:, **values)
          keys.map do |key|
            pkey = ([prefix] + key).join(separator)

            self.class.pack(hash: values).each do |k, c|
              client.hincrby(pkey, k, c)
            end
          end
        end

        def set(keys:, **values)
          keys.map do |key|
            pkey = ([prefix] + key).join(separator)

            client.hmset(pkey, *self.class.pack(hash: values))
          end
        end

        def get(keys:)
          keys.map do |key|
            pkey = ([prefix] + key).join(separator)

            self.class.unpack(
              hash: client.hgetall(pkey)
            )
          end
        end
      end
    end
  end
end
