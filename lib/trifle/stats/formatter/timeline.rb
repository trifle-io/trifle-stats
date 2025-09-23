# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Timeline
        Trifle::Stats::Series.register_formatter(:timeline, self)

        def format(series:, path:, slices: 1, &block) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          return {} if series[:at].empty?

          values = series[:values] || []
          segments = PathUtils.split_path(path)
          resolved_paths = PathUtils.resolve_concrete_paths(values, segments)
          zipped = series[:at].zip(values)

          resolved_paths.each_with_object({}) do |path_segments, acc|
            full_key = path_segments.join('.')
            timeline = zipped.map do |at, data|
              value = PathUtils.fetch_path(data, path_segments)
              [at, value]
            end

            acc[full_key] = formatted_timeline(result: timeline, slices: slices, block: block)
          end
        end

        private

        def formatted_timeline(result:, slices:, block: nil)
          sliced = sliced(result: result, slices: slices, block: block)
          slices == 1 ? sliced.first : sliced
        end

        def sliced(result:, slices:, block: nil)
          return [] if result.empty?

          slice_size = result.count / slices
          remainder = result.count - (slice_size * slices)
          relevant = result[remainder..]

          relevant.each_slice(slice_size).map do |slice|
            slice.map do |at, value|
              block ? block.call(at, value) : [at, value.to_f]
            end
          end
        end
      end
    end
  end
end
