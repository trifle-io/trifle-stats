# frozen_string_literal: true

require 'redis'

module Trifle
  module Ruby
    module Driver
      class Redis
        attr_accessor :prefix

        def initialize(client = ::Redis.current, prefix: 'bw')
          @client = client
          @prefix = prefix
        end

        def inc(key:, **values)
          pkey = [@prefix, key].join('::')
          values.each do |k, c|
            @client.hincrby(pkey, k, c)
          end
        end

        def get(key:)
          pkey = [@prefix, key].join('::')
          @client.hgetall(pkey)
        end
      end
    end
  end
end
