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
            at = Nocturnal.new(@at, config: config).floor(pgrn.offset, pgrn.unit)
            Nocturnal::Key.new(key: key, granularity: granularity, at: at)
          end

          def perform
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

          def tracking_key
            @untracked ? '__untracked__' : nil
          end
        end
      end
    end
  end
end
