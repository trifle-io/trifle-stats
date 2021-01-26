# frozen_string_literal: true

module Trifle
  module Ruby
    class Resource
      include Mixins::Packer
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
        packed = self.class.pack(hash: values)
        config.driver.inc(key: full_key, **packed)
        {
          at => values
        }
      end

      def values
        {
          at => self.class.unpack(
            hash: config.driver.get(key: full_key)
          )
        }
      end

      def config
        @configuration || Trifle::Ruby.config
      end
    end
  end
end
