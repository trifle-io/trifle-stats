# frozen_string_literal: true

module Trifle
  module Stats
    class Nocturnal
      class Key
        attr_reader :key, :granularity, :at
        attr_accessor :prefix

        def initialize(key:, granularity: nil, at: nil)
          @prefix = nil
          @key = key
          @granularity = granularity
          @at = at
        end

        def join(separator)
          [prefix, key, granularity, at&.to_i].compact.join(separator)
        end

        def identifier(separator, mode = :full)
          mode = normalize_join_mode(mode)

          return { key: key, granularity: granularity, at: at }.compact if mode == :separated

          raise ArgumentError, 'separator must be a String for joined identifiers' if separator.nil?

          if mode == :partial
            { key: partial_join(separator), at: at }.compact
          else
            { key: join(separator) }
          end
        end

        private

        def normalize_join_mode(mode)
          return :separated if mode.nil?

          mode = mode.to_sym if mode.is_a?(String)
          return mode if %i[full partial].include?(mode)

          raise ArgumentError, 'mode must be nil, :full, "full", :partial, or "partial"'
        end

        def partial_join(separator)
          [prefix, key, granularity].compact.join(separator)
        end
      end
    end
  end
end
