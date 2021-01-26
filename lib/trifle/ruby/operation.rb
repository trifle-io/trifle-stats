# frozen_string_literal: true

module Trifle
  module Ruby
    class Operation
      def initialize(**params)
        params.each do |k, v|
          instance_variable_set("@#{k}", v)
        end
      end

      def config
        @configuration || Trifle::Ruby.config
      end
    end
  end
end
