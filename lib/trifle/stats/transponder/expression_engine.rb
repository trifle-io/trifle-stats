# frozen_string_literal: true

require 'bigdecimal'

module Trifle
  module Stats
    class Transponder
      class ExpressionEngine
        LETTERS = ('a'..'z').to_a.freeze
        TOKEN_OPERATORS = %w[+ - * / ( ) ,].freeze
        NUMBER_PATTERN = /\A\d+(?:\.\d+)?/.freeze
        IDENT_PATTERN = /\A[A-Za-z_][A-Za-z0-9_]*/.freeze

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
            trimmed = normalize_expression_text(expression)
            tokens = []
            index = 0

            while index < trimmed.length
              token, consumed = read_token(trimmed, index)
              tokens << token unless token.nil?
              index += consumed
            end

            tokens
          end

          def normalize_expression_text(expression)
            trimmed = expression.to_s.strip
            raise ArgumentError, 'Expression must be text.' if trimmed.empty?

            trimmed
          end

          def read_token(source, index)
            char = source[index]

            return [nil, 1] if whitespace?(char)
            return [char, 1] if operator?(char)
            return number_token(source, index) if digit?(char)
            return ident_token(source, index) if identifier_start?(char)

            raise_invalid_token(index)
          end

          def whitespace?(char)
            char.match?(/\s/)
          end

          def operator?(char)
            TOKEN_OPERATORS.include?(char)
          end

          def digit?(char)
            char.match?(/\d/)
          end

          def identifier_start?(char)
            char.match?(/[A-Za-z_]/)
          end

          def number_token(source, index)
            match = source[index..].match(NUMBER_PATTERN)
            raise_invalid_token(index) unless match

            [[:number, BigDecimal(match[0])], match[0].length]
          end

          def ident_token(source, index)
            match = source[index..].match(IDENT_PATTERN)
            raise_invalid_token(index) unless match

            [[:ident, match[0]], match[0].length]
          end

          def raise_invalid_token(index)
            raise ArgumentError, "Invalid token at position #{index}."
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
            return parse_unary_factor if %w[+ -].include?(current)
            return parse_grouped_expression if current == '('

            parse_primary
          end

          def parse_primary
            token = current
            raise ArgumentError, 'Unexpected end of expression.' if token.nil?

            return parse_number(token) if number_token?(token)
            return parse_identifier(token) if ident_token?(token)

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

          def parse_unary_factor
            operator = consume
            node = parse_factor
            operator == '-' ? [:neg, node] : node
          end

          def parse_grouped_expression
            consume
            node = parse_expression
            expect_token!(')', 'Missing closing parenthesis.')
            consume
            node
          end

          def parse_number(token)
            consume
            [:number, token[1]]
          end

          def parse_identifier(token)
            consume
            ident = token[1]
            return parse_function_call(ident) if current == '('

            validate_variable!(ident)
            [:var, ident]
          end

          def parse_function_call(ident)
            consume
            args = parse_args
            expect_token!(')', 'Missing closing parenthesis.')
            consume
            [:func, ident, args]
          end

          def validate_variable!(ident)
            raise ArgumentError, "Unknown variable #{ident}." unless @vars.include?(ident)
          end

          def number_token?(token)
            token.is_a?(Array) && token[0] == :number
          end

          def ident_token?(token)
            token.is_a?(Array) && token[0] == :ident
          end

          def expect_token!(expected, message)
            raise ArgumentError, message unless current == expected
          end
        end

        class Evaluator
          ZERO = BigDecimal('0')
          AVERAGE = lambda do |args|
            args.reduce(ZERO, :+) / BigDecimal(args.length.to_s)
          end
          BINARY_OPERATIONS = {
            :+ => ->(left, right) { left + right },
            :- => ->(left, right) { left - right },
            :* => ->(left, right) { left * right },
            :/ => ->(left, right) { right.zero? ? nil : left / right }
          }.freeze
          FUNCTIONS = {
            'sum' => ->(args) { args.reduce(ZERO, :+) },
            'mean' => AVERAGE,
            'avg' => AVERAGE,
            'min' => :min.to_proc,
            'max' => :max.to_proc
          }.freeze

          def initialize(env)
            @env = env || {}
          end

          def evaluate(node)
            type, *rest = node
            return rest[0] if type == :number
            return evaluate_variable(rest[0]) if type == :var
            return evaluate_negation(rest[0]) if type == :neg
            return evaluate_binary(type, rest[0], rest[1]) if BINARY_OPERATIONS.key?(type)
            return evaluate_function(rest[0], rest[1]) if type == :func

            raise ArgumentError, "Unknown AST node #{type.inspect}."
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

          def evaluate_variable(name)
            normalize_value(@env[name])
          end

          def evaluate_negation(node)
            value = evaluate(node)
            value.nil? ? nil : -value
          end

          def evaluate_binary(operator, left_node, right_node)
            left = evaluate(left_node)
            right = evaluate(right_node)
            apply_binary(operator, left, right)
          end

          def evaluate_function(name, arg_nodes)
            args = arg_nodes.map { |arg| evaluate(arg) }
            apply_function(name, args)
          end

          def apply_binary(operator, left, right)
            return nil if left.nil? || right.nil?

            operation = BINARY_OPERATIONS[operator]
            raise ArgumentError, "Unknown binary operator #{operator.inspect}." unless operation

            operation.call(left, right)
          end

          def apply_function(name, args)
            return nil if args.empty? || args.any?(&:nil?)

            return apply_sqrt(args) if name == 'sqrt'

            function = FUNCTIONS[name]
            raise ArgumentError, "Unknown function #{name}." unless function

            function.call(args)
          end

          def apply_sqrt(args)
            raise ArgumentError, 'Function sqrt expects 1 argument.' unless args.length == 1
            return nil if args[0].negative?

            BigDecimal(Math.sqrt(args[0].to_f).to_s)
          end
        end
      end
    end
  end
end
