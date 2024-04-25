# frozen_string_literal: true

module Trifle
  module Stats
    class Aggregator
      class Min
        Trifle::Stats::Series.register_aggregator(:min, self)

        def aggregate(series:, path:)
          keys = path.split('.')
          result = series[:values].map do |data|
            data.dig(*keys).to_f
          end
          result.min
        end
      end
    end
  end
end
