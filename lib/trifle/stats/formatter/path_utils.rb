# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      require 'set'

      module PathUtils
        module_function

        def split_path(path)
          return [] if path.nil? || path.empty?

          path.split('.').map(&:to_s)
        end

        def resolve_paths(values_list, segments)
          expand(values_list, segments, []).uniq
        end

        def resolve_concrete_paths(values_list, segments)
          if segments.include?('*')
            resolve_paths(values_list, segments)
          elsif map_target?(values_list, segments)
            expanded = resolve_paths(values_list, segments + ['*'])
            expanded.empty? ? [segments] : expanded
          else
            [segments]
          end
        end

        def fetch_path(data, segments)
          segments.reduce(data) do |current, segment|
            break nil unless current.is_a?(Hash)

            fetch_segment(current, segment)
          end
        end

        def expand(values_list, segments, acc)
          return [acc] if segments.empty?

          segment, *rest = segments

          if segment == '*'
            collect_keys(values_list, acc).flat_map do |key|
              expand(values_list, rest, acc + [key])
            end
          else
            expand(values_list, rest, acc + [segment])
          end
        end

        def collect_keys(values_list, acc)
          values_list.each_with_object(Set.new) do |value, keys|
            result = fetch_path(value, acc)
            next unless result.is_a?(Hash)

            result.each_key { |key| keys << normalize_key(key) }
          end.to_a
        end

        def fetch_segment(map, segment)
          return unless map.is_a?(Hash)

          key_candidates(segment).each do |key|
            return map[key] if key && map.key?(key)
          end

          nil
        end

        def key_candidates(segment)
          candidates = [segment]
          candidates << segment.to_sym if segment.respond_to?(:to_sym)

          numeric = integer_from_segment(segment)
          candidates << numeric if numeric

          candidates
        end

        def integer_from_segment(segment)
          Integer(segment, exception: false)
        end

        def normalize_key(key)
          key.to_s
        end

        def map_target?(values_list, segments)
          values_list.any? do |value|
            fetch_path(value, segments).is_a?(Hash)
          end
        end
      end
    end
  end
end
