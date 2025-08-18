# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class StandardDeviation
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:standard_deviation, self)

        def transpond(series:, sum:, count:, square:, response: 'sd') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          sum_keys = sum.to_s.split('.')
          count_keys = count.to_s.split('.')
          square_keys = square.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dcount = data.dig(*count_keys)
            dsquare = data.dig(*square_keys)
            dsum = data.dig(*sum_keys)
            next data unless dcount && dsquare && dsum

            dres = Math.sqrt(
              (dcount * dsquare - dsum * dsum) / (dcount * (dcount - 1)) # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
            )
            signal = {
              response => dres.nan? ? BigDecimal(0) : dres
            }
            self.class.deep_merge(data, self.class.unpack(hash: signal))
          end
          series
        end
      end
    end
  end
end
