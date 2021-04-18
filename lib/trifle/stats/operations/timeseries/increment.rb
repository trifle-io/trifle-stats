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

          def perform
            config.ranges.map do |range|
              at = Nocturnal.new(@at, config: config).send(range)
              config.driver.inc(
                key: [key, range, at.to_i],
                **values
              )
            end
          end
        end
      end
    end
  end
end
