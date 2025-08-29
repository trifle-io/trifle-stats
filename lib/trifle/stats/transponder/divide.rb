# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Divide
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:divide, self)

        def transpond(series:, left:, right:, response: 'divide') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          left_keys = left.to_s.split('.')
          right_keys = right.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dleft = data.dig(*left_keys)
            dright = data.dig(*right_keys)
            next data unless dleft && dright

            dres = (dleft / dright)
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
