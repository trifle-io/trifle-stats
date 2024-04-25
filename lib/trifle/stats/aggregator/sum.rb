# frozen_string_literal: true

module Trifle
  module Stats
    class Aggregator
      class Sum
        Trifle::Stats::Series.register_aggregator(:sum, self)

        def aggregate(series:, path:)
          keys = path.split('.')
          result = series[:values].map do |data|
            data.dig(*keys).to_f
          end
          result.sum
        end
      end
    end
  end
end
