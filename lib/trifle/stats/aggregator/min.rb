# frozen_string_literal: true

module Trifle
  module Stats
    class Aggregator
      class Min
        Trifle::Stats::Series.register_aggregator(:min, self)

        def aggregate(series:, path:, slices: 1)
          keys = path.split('.')
          result = series[:values].map do |data|
            data.dig(*keys)
          end
          sliced(result: result, slices: slices)
        end

        def sliced(result:, slices:)
          result[(result.count - (result.count / slices * slices))..].each_slice(result.count / slices).map(&:min)
        end
      end
    end
  end
end
