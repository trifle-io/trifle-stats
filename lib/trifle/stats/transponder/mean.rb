# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Mean
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:mean, self)

        def transpond(series:, paths:, response: 'mean') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          path_keys = paths.map { |path| path.to_s.split('.') }

          series[:values] = series[:values].map do |data|
            dvalues = path_keys.map { |path_key| data.dig(*path_key) }
            next data if dvalues.any?(&:nil?)

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
