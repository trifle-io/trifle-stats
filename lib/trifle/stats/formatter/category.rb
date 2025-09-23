# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Category
        Trifle::Stats::Series.register_formatter(:category, self)

        def format(series:, path:, slices: 1, &block)
          values = series[:values] || []
          return {} if values.empty?

          segments = PathUtils.split_path(path)
          resolved_paths = PathUtils.resolve_concrete_paths(values, segments)

          aggregated = slice(values_list: values, resolved_paths: resolved_paths, slices: slices, block: block)
          slices == 1 ? aggregated.first : aggregated
        end

        private

        def slice(values_list:, resolved_paths:, slices:, block: nil)
          return [] if values_list.empty?

          slice_size = values_list.count / slices
          remainder = values_list.count - (slice_size * slices)
          relevant = values_list[remainder..]

          relevant.each_slice(slice_size).map do |slice_values|
            aggregate_slice(slice_values: slice_values, resolved_paths: resolved_paths, block: block)
          end
        end

        def aggregate_slice(slice_values:, resolved_paths:, block: nil)
          slice_values.each_with_object(Hash.new(0.0)) do |data, acc|
            resolved_paths.each do |path_segments|
              full_key = path_segments.join('.')
              raw_value = PathUtils.fetch_path(data, path_segments)

              key, numeric_value = apply_transform(block, full_key, raw_value)
              acc[key] += (numeric_value || 0).to_f
            end
          end
        end

        def apply_transform(block, key, value)
          return [key, value] unless block

          result = block.call(key, value)
          if result.is_a?(Array) && result.size == 2
            [result[0].to_s, result[1]]
          else
            [key, result]
          end
        end
      end
    end
  end
end
