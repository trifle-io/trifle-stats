# frozen_string_literal: true

module Trifle
  module Ruby
    class Client
      def get(key:)
        driver.get(key: key)
      end

      def inc(key:, **values)
        driver.inc(key: key, **values)
      end

      private

      def driver
        @driver ||= Trifle::Ruby.config.driver
      end
    end
  end
end
