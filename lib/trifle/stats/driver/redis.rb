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

        def system_data_for(key:, count: 1, tracking_key: nil)
          tracking_key ||= key.key
          self.class.pack(hash: { count: count, keys: { tracking_key => count } })
        end

        def inc(keys:, values:, count: 1, tracking_key: nil) # rubocop:disable Metrics/MethodLength
          packed = self.class.pack(hash: values)
          client.pipelined do |pipeline|
            keys.each do |key|
              key.prefix = prefix
              pkey = key.join(separator)

              packed.each do |k, c|
                pipeline.hincrby(pkey, k, c)
              end
              track_system_data(pipeline, key, count, tracking_key)
            end
          end
        end

        def set(keys:, values:, count: 1, tracking_key: nil)
          packed = self.class.pack(hash: values)
          client.pipelined do |pipeline|
            keys.each do |key|
              key.prefix = prefix
              pkey = key.join(separator)

              pipeline.hmset(pkey, *packed)
              track_system_data(pipeline, key, count, tracking_key)
            end
          end
        end

        def get(keys:)
          results = client.pipelined do |pipeline|
            keys.each do |key|
              key.prefix = prefix
              pipeline.hgetall(key.join(separator))
            end
          end

          results.map { |hash| self.class.unpack(hash: hash) }
        end

        def ping(*)
          []
        end

        def scan(*)
          []
        end

        private

        def track_system_data(pipeline, key, count, tracking_key)
          return unless @system_tracking

          skey = system_join_for(key: key)
          system_data_for(key: key, count: count, tracking_key: tracking_key).each do |k, c|
            pipeline.hincrby(skey, k, c)
          end
        end
      end
    end
  end
end
