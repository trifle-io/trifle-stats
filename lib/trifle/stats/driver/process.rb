# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Process
        include Mixins::Packer
        def initialize
          @data = {}
        end

        def inc(key:, **values)
          self.class.pack(hash: values).each do |k, c|
            d = @data.fetch(key, {})
            d[k] = d[k].to_i + c
            @data[key] = d
          end
        end

        def set(key:, **values)
          self.class.pack(hash: values).each do |k, c|
            d = @data.fetch(key, {})
            d[k] = c
            @data[key] = d
          end
        end

        def get(key:)
          self.class.unpack(
            hash: @data.fetch(key, {})
          )
        end
      end
    end
  end
end
