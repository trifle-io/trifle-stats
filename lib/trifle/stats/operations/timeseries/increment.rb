# frozen_string_literal: true

module Trifle
  module Stats
    module Operations
      module Timeseries
        class Increment
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

          def key_for(range:)
            at = Nocturnal.new(@at, config: config).send(range)
            [key, range, at.to_i]
          end

          def perform
            config.driver.inc(
              keys: config.ranges.map { |range| key_for(range: range) },
              **values
            )
          end
        end
      end
    end
  end
end
