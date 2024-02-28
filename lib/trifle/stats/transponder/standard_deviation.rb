# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class StandardDeviation
        include Trifle::Stats::Mixins::Packer

        attr_reader :sum, :count, :square

        def initialize(sum: 'sum', count: 'count', square: 'square')
          @sum = sum
          @count = count
          @square = square
        end

        def transpond(series:, path:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          keys = path.split('.')

          series[:values] = series[:values].map do |data|
            dcount = data.dig(*keys, count)
            dsquare = data.dig(*keys, square)
            dsum = data.dig(*keys, sum)
            signal = {
              "#{path}.sd" => Math.sqrt(
                (dcount * dsquare - dsum * dsum) / (dcount * (dcount - 1)) # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
              )
            }
            self.class.deep_merge(data, self.class.unpack(hash: signal))
          end
          series
        end
      end
    end
  end
end
