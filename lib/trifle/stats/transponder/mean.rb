# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Mean
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:mean, self)

        def transpond(series:, values:, response: 'mean') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          values_keys = values.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dvalues = data.dig(*values_keys)
            next data unless dvalues && dvalues.is_a?(Array)

            numeric_values = dvalues.select { |v| v.is_a?(Numeric) }
            next data if numeric_values.empty?

            dres = (numeric_values.sum.to_f / numeric_values.length)
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
