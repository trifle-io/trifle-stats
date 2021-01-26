# frozen_string_literal: true

module Trifle
  module Ruby
    class Resource
      attr_accessor :key, :range, :at, :configuration

      def initialize(key:, range:, at:, configuration: nil)
        @configuration = configuration
        @key = key
        @range = range
        @at = at
      end

      def full_key
        [key, range, at.to_i].join(Trifle::Ruby.config.separator)
      end

      def increment(**values)
        config.driver.inc(key: full_key, **values)
        {
          at => values
        }
      end

      def values
        {
          at => config.driver.get(key: full_key)
        }
      end

      def config
        @configuration || Trifle::Ruby.config
      end
    end
  end
end
