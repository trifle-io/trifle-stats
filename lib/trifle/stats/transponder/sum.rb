# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Sum
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:sum, self)

        def transpond(series:, values:, response: 'sum') # rubocop:disable Metrics/MethodLength
          values_keys = values.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dvalues = data.dig(*values_keys)
            next data unless dvalues && dvalues.is_a?(Array)

            dres = dvalues.sum { |v| v.is_a?(Numeric) ? v : 0 }
            signal = {
              response => dres
            }
            self.class.deep_merge(data, self.class.unpack(hash: signal))
          end
          series
        end
      end
    end
  end
end
