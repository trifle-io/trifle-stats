# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class StandardDeviation
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:standard_deviation, self)

        def transpond(series:, left:, right:, square:, response: 'sd') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          left_keys = left.to_s.split('.')
          right_keys = right.to_s.split('.')
          square_keys = square.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dright = data.dig(*right_keys)
            dsquare = data.dig(*square_keys)
            dleft = data.dig(*left_keys)
            next data unless dright && dsquare && dleft

            dres = Math.sqrt(
              (dright * dsquare - dleft * dleft) / (dright * (dright - 1)) # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
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
