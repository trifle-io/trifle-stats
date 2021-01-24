# frozen_string_literal: true

module Trifle
  module Ruby
    class Resource
      include Mixins::Packer
      attr_accessor :key, :range, :at

      def initialize(key:, range:, at:)
        @key = key
        @range = range
        @at = at
      end

      def full_key
        [key, range, at.to_i].join(Trifle::Ruby.config.separator)
      end

      def increment(**values)
        packed = self.class.pack(hash: values)
        Trifle::Ruby.client.inc(key: full_key, **packed)
        {
          at => values
        }
      end

      def values
        {
          at => self.class.unpack(
            hash: Trifle::Ruby.client.get(key: full_key)
          )
        }
      end
    end
  end
end
