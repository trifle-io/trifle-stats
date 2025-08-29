# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Sum
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:sum, self)

        def transpond(series:, paths:, response: 'sum') # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
          path_keys = paths.map { |path| path.to_s.split('.') }

          series[:values] = series[:values].map do |data|
            dvalues = path_keys.map { |path_key| data.dig(*path_key) }
            next data if dvalues.any?(&:nil?)

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
