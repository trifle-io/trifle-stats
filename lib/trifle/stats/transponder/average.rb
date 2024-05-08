# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Average
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:average, self)

        def transpond(series:, path:, key: 'average', sum: 'sum', count: 'count') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          keys = path.to_s.split('.')
          sum = sum.to_s.split('.')
          count = count.to_s.split('.')
          key = [path, key].compact.join('.')
          series[:values] = series[:values].map do |data|
            dsum = data.dig(*keys, *sum)
            dcount = data.dig(*keys, *count)
            next data unless dsum && dcount

            dres = (dsum / dcount)
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
