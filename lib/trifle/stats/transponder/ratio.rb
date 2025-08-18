# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Ratio
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:ratio, self)

        def transpond(series:, sample:, total:, response: 'ratio') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          sample_keys = sample.to_s.split('.')
          total_keys = total.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dsample = data.dig(*sample_keys)
            dtotal = data.dig(*total_keys)
            next data unless dsample && dtotal

            dres = (dsample / dtotal) * 100
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
