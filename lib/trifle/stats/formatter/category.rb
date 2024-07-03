# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Category
        Trifle::Stats::Series.register_formatter(:category, self)

        def format(series:, path:, slices: 1, &block)
          return [] if series[:at].empty?

          keys = path.split('.')
          result = series[:at].zip(series[:values].map { |v| v.dig(*keys) || {} })
          sliced(result: result, slices: slices, block: block)
        end

        private

        def sliced(result:, slices:, block: nil) # rubocop:disable Metrics/AbcSize
          result[(result.count - (result.count / slices * slices))..].each_slice(result.count / slices).map do |slice|
            slice.each_with_object(Hash.new(0)) do |(_at, data), map|
              data.each do |key, value|
                k, v = block ? block.call(key, value) : [key.to_s, value.to_f]
                map[k] += v
              end
            end
          end
        end
      end
    end
  end
end
