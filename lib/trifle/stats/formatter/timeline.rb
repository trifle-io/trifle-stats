# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Timeline
        Trifle::Stats::Series.register_formatter(:timeline, self)

        def format(series:, path:, slices: 1, &block)
          return [] if series[:at].empty?

          keys = path.split('.')
          result = series[:at].zip(series[:values].map { |v| v.dig(*keys) })
          sliced(result: result, slices: slices, block: block)
        end

        private

        def sliced(result:, slices:, block: nil)
          result[(result.count - (result.count / slices * slices))..].each_slice(result.count / slices).map do |slice|
            slice.map do |at, value|
              block ? block.call(at, value) : [at, value.to_f]
            end
          end
        end
      end
    end
  end
end
