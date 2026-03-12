# frozen_string_literal: true

require 'bigdecimal'

module Trifle
  module Stats
    class Transponder
      class ExpressionEngine
        LETTERS = ('a'..'z').to_a.freeze

        class << self
          def max_vars
            LETTERS.length
          end

          def allowed_vars(count)
            LETTERS.take(count)
          end

          def validate(paths:, expression:)
            normalized_paths = normalize_paths(paths)
            parse(expression: expression, paths: normalized_paths)
            true
          end

          def parse(expression:, paths:)
            normalized_paths = normalize_paths(paths)
            ensure_within_var_limit(normalized_paths)
            tokens = tokenize(expression.to_s)
            parser = Parser.new(tokens, allowed_vars(normalized_paths.length))
            ast = parser.parse
            raise ArgumentError, 'Unexpected token sequence.' unless parser.done?

            ast
          end

          def evaluate(ast:, env:)
            Evaluator.new(env).evaluate(ast)
          end

          private

          def normalize_paths(paths)
            raise ArgumentError, 'Paths must be an array.' unless paths.is_a?(Array)

            cleaned = paths.map { |path| path.to_s.strip }.reject(&:empty?)
            raise ArgumentError, 'At least one path is required.' if cleaned.empty?

            cleaned
          end

          def ensure_within_var_limit(paths)
            return if paths.length <= max_vars

            raise ArgumentError, "Too many paths. Maximum supported is #{max_vars}."
          end

          def tokenize(expression)
            trimmed = expression.to_s.strip
            raise ArgumentError, 'Expression must be text.' if trimmed.empty?

            tokens = []
            index = 0

            while index < trimmed.length
              char = trimmed[index]

              if char.match?(/\s/)
                index += 1
                next
              end

              if %w[+ - * / ( ) ,].include?(char)
                tokens << char
                index += 1
                next
              end

              if char.match?(/\d/)
                match = trimmed[index..].match(/\A\d+(?:\.\d+)?/)
                raise ArgumentError, "Invalid token at position #{index}." unless match

                tokens << [:number, BigDecimal(match[0])]
                index += match[0].length
                next
              end

              if char.match?(/[A-Za-z_]/)
                match = trimmed[index..].match(/\A[A-Za-z_][A-Za-z0-9_]*/)
                raise ArgumentError, "Invalid token at position #{index}." unless match

                tokens << [:ident, match[0]]
                index += match[0].length
                next
              end

              raise ArgumentError, "Invalid token at position #{index}."
            end

            tokens
          end
        end

        class Parser
          def initialize(tokens, vars)
            @tokens = tokens
            @vars = vars
            @index = 0
          end

          def parse
            parse_expression
          end

          def done?
            current.nil?
          end

          private

          def parse_expression
            node = parse_term

            while %w[+ -].include?(current)
              op = consume
              node = [op.to_sym, node, parse_term]
            end

            node
          end

          def parse_term
            node = parse_factor

            while %w[* /].include?(current)
              op = consume
              node = [op.to_sym, node, parse_factor]
            end

            node
          end

          def parse_factor
            case current
            when '+'
              consume
              parse_factor
            when '-'
              consume
              [:neg, parse_factor]
            when '('
              consume
              node = parse_expression
              raise ArgumentError, 'Missing closing parenthesis.' unless current == ')'

              consume
              node
            else
              parse_primary
            end
          end

          def parse_primary
            token = current
            raise ArgumentError, 'Unexpected end of expression.' if token.nil?

            if token.is_a?(Array) && token[0] == :number
              consume
              return [:number, token[1]]
            end

            if token.is_a?(Array) && token[0] == :ident
              consume
              ident = token[1]

              if current == '('
                consume
                args = parse_args
                raise ArgumentError, 'Missing closing parenthesis.' unless current == ')'

                consume
                return [:func, ident, args]
              end

              raise ArgumentError, "Unknown variable #{ident}." unless @vars.include?(ident)

              return [:var, ident]
            end

            raise ArgumentError, "Unexpected token #{token.inspect}."
          end

          def parse_args
            return [] if current == ')'

            args = [parse_expression]

            while current == ','
              consume
              args << parse_expression
            end

            args
          end

          def current
            @tokens[@index]
          end

          def consume
            token = current
            @index += 1
            token
          end
        end

        class Evaluator
          def initialize(env)
            @env = env || {}
          end

          def evaluate(node)
            type, *rest = node

            case type
            when :number
              rest[0]
            when :var
              normalize_value(@env[rest[0]])
            when :neg
              value = evaluate(rest[0])
              value.nil? ? nil : (-value)
            when :+, :-, :*, :/
              apply_binary(type, evaluate(rest[0]), evaluate(rest[1]))
            when :func
              apply_function(rest[0], rest[1].map { |arg| evaluate(arg) })
            else
              raise ArgumentError, "Unknown AST node #{type.inspect}."
            end
          end

          private

          def normalize_value(value)
            return nil if value.nil?
            return value if value.is_a?(BigDecimal)
            return BigDecimal(value.to_s) if value.is_a?(Numeric)

            nil
          rescue ArgumentError
            nil
          end

          def apply_binary(_op, nil, _right)
            nil
          end

          def apply_binary(_op, _left, nil)
            nil
          end

          def apply_binary(:+, left, right)
            left + right
          end

          def apply_binary(:-, left, right)
            left - right
          end

          def apply_binary(:*, left, right)
            left * right
          end

          def apply_binary(:/, _left, right)
            return nil if right.zero?

            _left / right
          end

          def apply_function(name, args)
            return nil if args.empty? || args.any?(&:nil?)

            case name
            when 'sum'
              args.reduce(BigDecimal('0'), :+)
            when 'mean', 'avg'
              args.reduce(BigDecimal('0'), :+) / BigDecimal(args.length.to_s)
            when 'min'
              args.min
            when 'max'
              args.max
            when 'sqrt'
              raise ArgumentError, 'Function sqrt expects 1 argument.' unless args.length == 1

              return nil if args[0].negative?

              BigDecimal(Math.sqrt(args[0].to_f).to_s)
            else
              raise ArgumentError, "Unknown function #{name}."
            end
          end
        end
      end
    end
  end
end
