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
          end

          def config
            @config || Trifle::Stats.default
          end

          def key_for(granularity:)
            at = Nocturnal.new(@at, config: config).send(granularity)
            Nocturnal::Key.new(key: key, granularity: granularity, at: at)
          end

          def perform
            config.driver.set(
              keys: config.granularities.map { |granularity| key_for(granularity: granularity) },
              **values
            )
          end
        end
      end
    end
  end
end
