# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Average
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:average, self)

        def transpond(series:, sum:, count:, response: 'average') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          sum_keys = sum.to_s.split('.')
          count_keys = count.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dsum = data.dig(*sum_keys)
            dcount = data.dig(*count_keys)
            next data unless dsum && dcount

            dres = (dsum / dcount)
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
