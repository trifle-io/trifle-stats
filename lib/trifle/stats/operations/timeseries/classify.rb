# frozen_string_literal: true

module Trifle
  module Stats
    module Operations
      module Timeseries
        class Classify
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

          def deep_classify(hash)
            hash.transform_values do |value|
              next deep_classify(value) if value.is_a?(Hash)

              { classify(value) => 1 }
            end
          end

          def classify(value)
            config.designator.designate(value: value).to_s.gsub('.', '_')
          end

          def key_for(range:)
            at = Nocturnal.new(@at, config: config).send(range)
            [key, range, at.to_i]
          end

          def perform
            config.driver.inc(
              keys: config.ranges.map { |range| key_for(range: range) },
              **deep_classify(values)
            )
          end
        end
      end
    end
  end
end
