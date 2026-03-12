# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Expression
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:expression, self)

        def transpond(series:, paths:, expression:, response:)
          normalized_paths = normalize_paths(paths)
          normalized_response = response.to_s.strip

          ensure_response!(normalized_response)
          ensure_no_wildcards!(normalized_paths, normalized_response)

          ast = ExpressionEngine.parse(expression: expression, paths: normalized_paths)

          series[:values] = series[:values].map do |data|
            env = build_env(data, normalized_paths)
            value = ExpressionEngine.evaluate(ast: ast, env: env)
            put_response(data, normalized_response, value)
          end

          series
        end

        def validate(paths:, expression:, response:)
          normalized_paths = normalize_paths(paths)
          normalized_response = response.to_s.strip

          ensure_response!(normalized_response)
          ensure_no_wildcards!(normalized_paths, normalized_response)
          ExpressionEngine.validate(paths: normalized_paths, expression: expression)
        end

        private

        def normalize_paths(paths)
          raise ArgumentError, 'Paths must be an array.' unless paths.is_a?(Array)

          cleaned = paths.map { |path| path.to_s.strip }.reject(&:empty?)
          raise ArgumentError, 'At least one path is required.' if cleaned.empty?

          cleaned
        end

        def ensure_response!(response)
          raise ArgumentError, 'Response path is required.' if response.empty?
        end

        def ensure_no_wildcards!(paths, response)
          wildcard = paths.any? { |path| path.include?('*') } || response.include?('*')
          raise ArgumentError, 'Wildcard paths are not supported yet.' if wildcard
        end

        def build_env(data, paths)
          ExpressionEngine.allowed_vars(paths.length).zip(paths).to_h do |var, path|
            [var, data.dig(*path.split('.'))]
          end
        end

        def put_response(data, response, value)
          keys = response.split('.')
          raise ArgumentError, "Cannot write to response path #{response}." unless can_create_path?(data, keys)

          updated = deep_dup(data)
          target = updated

          keys[0..-2].each do |key|
            target[key] ||= {}
            target = target[key]
          end

          target[keys[-1]] = value
          updated
        end

        def can_create_path?(data, keys)
          return true if keys.length <= 1

          current = data

          keys[0..-2].each do |key|
            value = current[key]
            return true if value.nil?
            return false unless value.is_a?(Hash)

            current = value
          end

          true
        end

        def deep_dup(value)
          case value
          when Hash
            value.each_with_object({}) { |(key, inner), out| out[key] = deep_dup(inner) }
          when Array
            value.map { |inner| deep_dup(inner) }
          else
            value
          end
        end
      end
    end
  end
end
