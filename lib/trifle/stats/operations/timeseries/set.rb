# frozen_string_literal: true

module Trifle
  module Stats
    module Operations
      module Timeseries
        class Set
          attr_reader :key, :values

          def initialize(**keywords)
            @key = keywords.fetch(:key)
            @at = keywords.fetch(:at)
            @values = keywords.fetch(:values)
            @config = keywords[:config]
            @untracked = keywords.fetch(:untracked, false)
          end

          def config
            @config || Trifle::Stats.default
          end

          def key_for(granularity:)
            pgrn = Nocturnal::Parser.new(granularity)
            at = Nocturnal.new(localized_time(@at), config: config).floor(pgrn.offset, pgrn.unit)
            Nocturnal::Key.new(key: key, granularity: granularity, at: at)
          end

          def perform
            return direct_write if direct_write?

            buffered_write
          end

          def tracking_key
            @untracked ? '__untracked__' : nil
          end

          private

          def direct_write?
            config.driver.respond_to?(:direct_write)
          end

          def direct_write
            config.driver.direct_write(**direct_payload)
          end

          def direct_payload
            { operation: :assert, key: key, at: @at, values: values, untracked: @untracked }
          end

          def buffered_write
            payload = {
              keys: config.granularities.map { |granularity| key_for(granularity: granularity) },
              values: values
            }

            if tracking_key
              config.storage.set(**payload.merge(tracking_key: tracking_key))
            else
              config.storage.set(**payload)
            end
          end

          def localized_time(time)
            base_time = time.is_a?(Time) ? time : time.to_time
            config.tz.utc_to_local(base_time.getutc)
          end
        end
      end
    end
  end
end
