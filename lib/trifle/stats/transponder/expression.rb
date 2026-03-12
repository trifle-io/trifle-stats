# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Expression
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:expression, self)

        def transpond(series:, paths:, expression:, response:)
          normalized_paths, normalized_response = normalized_config(paths, response)
          ast = ExpressionEngine.parse(expression: expression, paths: normalized_paths)
          series[:values] = transformed_values(series[:values], normalized_paths, normalized_response, ast)
          series
        end

        def validate(paths:, expression:, response:)
          normalized_paths, = normalized_config(paths, response)
          ExpressionEngine.validate(paths: normalized_paths, expression: expression)
        end

        private

        def normalized_config(paths, response)
          normalized_paths = normalize_paths(paths)
          normalized_response = normalize_response(response)

          ensure_no_wildcards!(normalized_paths, normalized_response)
          [normalized_paths, normalized_response]
        end

        def normalize_paths(paths)
          raise ArgumentError, 'Paths must be an array.' unless paths.is_a?(Array)

          cleaned = paths.map { |path| path.to_s.strip }.reject(&:empty?)
          raise ArgumentError, 'At least one path is required.' if cleaned.empty?

          cleaned
        end

        def normalize_response(response)
          normalized_response = response.to_s.strip
          ensure_response!(normalized_response)
          normalized_response
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

        def transformed_values(values, paths, response, ast)
          values.map { |data| transform_row(data, paths, response, ast) }
        end

        def transform_row(data, paths, response, ast)
          env = build_env(data, paths)
          value = ExpressionEngine.evaluate(ast: ast, env: env)
          put_response(data, response, value)
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
            value.transform_values { |inner| deep_dup(inner) }
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
