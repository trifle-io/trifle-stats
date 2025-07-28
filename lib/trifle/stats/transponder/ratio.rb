# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Ratio
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:ratio, self)

        def transpond(series:, path:, key: 'ratio', sample: 'sample', total: 'total') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          keys = path.to_s.split('.')
          sample = sample.to_s.split('.')
          total = total.to_s.split('.')
          key = path.to_s.empty? ? key : [path, key].join('.')
          series[:values] = series[:values].map do |data|
            dsample = data.dig(*keys, *sample)
            dtotal = data.dig(*keys, *total)
            next data unless dsample && dtotal

            dres = (dsample / dtotal) * 100
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
