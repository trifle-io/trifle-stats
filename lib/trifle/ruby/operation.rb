# frozen_string_literal: true

module Trifle
  module Ruby
    class Operation
      def config
        @configuration || Trifle::Ruby.config
      end
    end
  end
end
