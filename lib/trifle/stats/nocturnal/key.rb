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

        def identifier(separator)
          if separator
            { key: join(separator) }
          else
            { key: key, granularity: granularity, at: at }.compact
          end
        end
      end
    end
  end
end
