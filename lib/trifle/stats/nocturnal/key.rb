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
          if separator
            if normalize_join_mode(mode) == :partial
              { key: partial_join(separator), at: at }.compact
            else
              { key: join(separator) }
            end
          else
            { key: key, granularity: granularity, at: at }.compact
          end
        end

        private

        def normalize_join_mode(mode)
          return :full if mode.nil?
          mode = mode.to_sym if mode.is_a?(String)
          return mode if %i[full partial].include?(mode)

          raise ArgumentError, 'mode must be :full, "full", :partial, or "partial"'
        end

        def partial_join(separator)
          [prefix, key, granularity].compact.join(separator)
        end
      end
    end
  end
end
