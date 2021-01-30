# frozen_string_literal: true

require 'redis'
require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Redis
        include Mixins::Packer
        attr_accessor :prefix

        def initialize(client = ::Redis.current, prefix: 'trfl')
          @client = client
          @prefix = prefix
        end

        def inc(key:, **values)
          pkey = [@prefix, key].join('::')

          self.class.pack(hash: values).each do |k, c|
            @client.hincrby(pkey, k, c)
          end
        end

        def get(key:)
          pkey = [@prefix, key].join('::')

          self.class.unpack(
            hash: @client.hgetall(pkey)
          )
        end
      end
    end
  end
end
