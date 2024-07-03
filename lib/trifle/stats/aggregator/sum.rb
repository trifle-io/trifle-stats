# frozen_string_literal: true

module Trifle
  module Stats
    class Aggregator
      class Sum
        Trifle::Stats::Series.register_aggregator(:sum, self)

        def aggregate(series:, path:, slices: 1)
          return [] if series[:at].empty?

          keys = path.split('.')
          result = series[:values].map do |data|
            data.dig(*keys)
          end
          sliced(result: result, slices: slices)
        end

        private

        def sliced(result:, slices:)
          result[(result.count - (result.count / slices * slices))..].each_slice(result.count / slices).map do |slice|
            slice.compact.sum
          end
        end
      end
    end
  end
end
