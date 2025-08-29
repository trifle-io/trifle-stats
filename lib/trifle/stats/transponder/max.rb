# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Max
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:max, self)

        def transpond(series:, paths:, response: 'max') # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
          path_keys = paths.map { |path| path.to_s.split('.') }

          series[:values] = series[:values].map do |data|
            dvalues = path_keys.map { |path_key| data.dig(*path_key) }
            next data if dvalues.any?(&:nil?)

            numeric_values = dvalues.select { |v| v.is_a?(Numeric) }
            next data if numeric_values.empty?

            dres = numeric_values.max
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
