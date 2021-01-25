# frozen_string_literal: true

module Trifle
  module Ruby
    class Resource
      include Mixins::Packer
      attr_accessor :key, :range, :at, :driver

      def initialize(key:, range:, at:, driver: nil)
        @key = key
        @range = range
        @at = at
        @driver = driver
      end

      def full_key
        [key, range, at.to_i].join(Trifle::Ruby.config.separator)
      end

      def increment(**values)
        packed = self.class.pack(hash: values)
        driver.inc(key: full_key, **packed)
        {
          at => values
        }
      end

      def values
        {
          at => self.class.unpack(
            hash: driver.get(key: full_key)
          )
        }
      end

      def driver
        @driver ||= Trifle::Ruby.config.driver
      end
    end
  end
end
