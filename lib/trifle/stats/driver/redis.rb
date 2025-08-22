# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Redis
        include Mixins::Packer
        attr_accessor :client, :prefix, :separator

        def initialize(client, prefix: 'trfl', system_tracking: true)
          @client = client
          @prefix = prefix
          @system_tracking = system_tracking
          @separator = '::'
        end

        def description
          "#{self.class.name}(J)"
        end

        def system_join_for(key:)
          key = Nocturnal::Key.new(key: '__system__key__', granularity: key.granularity, at: key.at)
          key.prefix = prefix
          key.join(separator)
        end

        def system_data_for(key:)
          self.class.pack(hash: { count: 1, keys: { key.key => 1 } })
        end

        def inc(keys:, values:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          keys.map do |key|
            key.prefix = prefix
            pkey = key.join(separator)

            self.class.pack(hash: values).each do |k, c|
              client.hincrby(pkey, k, c)
            end
            next unless @system_tracking

            skey = system_join_for(key: key)
            system_data_for(key: key).each do |k, c|
              client.hincrby(skey, k, c)
            end
          end
        end

        def set(keys:, values:)
          keys.map do |key|
            key.prefix = prefix
            pkey = key.join(separator)

            client.hmset(pkey, *self.class.pack(hash: values))
            next unless @system_tracking

            skey = system_join_for(key: key)
            system_data_for(key: key).each do |k, c|
              client.hincrby(skey, k, c)
            end
          end
        end

        def get(keys:)
          keys.map do |key|
            key.prefix = prefix
            pkey = key.join(separator)

            self.class.unpack(
              hash: client.hgetall(pkey)
            )
          end
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
