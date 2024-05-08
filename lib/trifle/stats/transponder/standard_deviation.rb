# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class StandardDeviation
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:standard_deviation, self)

        def transpond(series:, path:, key: 'sd', sum: 'sum', count: 'count', square: 'square') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
          keys = path.to_s.split('.')
          sum = sum.to_s.split('.')
          count = count.to_s.split('.')
          square = square.to_s.split('.')
          key = [path, key].compact.join('.')
          series[:values] = series[:values].map do |data|
            dcount = data.dig(*keys, *count)
            dsquare = data.dig(*keys, *square)
            dsum = data.dig(*keys, *sum)
            next data unless dcount && dsquare && dsum

            dres = Math.sqrt(
              (dcount * dsquare - dsum * dsum) / (dcount * (dcount - 1)) # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
            )
            signal = {
              key => dres.nan? ? BigDecimal(0) : dres
            }
            self.class.deep_merge(data, self.class.unpack(hash: signal))
          end
          series
        end
      end
    end
  end
end
