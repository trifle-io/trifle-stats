# frozen_string_literal: true

module Trifle
  module Stats
    class Aggregator
      class Max
        Trifle::Stats::Series.register_aggregator(:max, self)

        def aggregate(series:, path:)
          keys = path.split('.')
          result = series[:values].map do |data|
            data.dig(*keys).to_f
          end
          result.max
        end
      end
    end
  end
end
