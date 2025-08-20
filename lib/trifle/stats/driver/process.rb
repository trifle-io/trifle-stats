# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Process
        include Mixins::Packer
        def initialize
          @data = {}
          @separator = '::'
        end

        def description
          "#{self.class.name}(J)"
        end

        def inc(keys:, values:)
          keys.map do |key|
            self.class.pack(hash: values).each do |k, c|
              d = @data.fetch(key.join(@separator), {})
              d[k] = d[k].to_i + c
              @data[key.join(@separator)] = d
            end
          end
        end

        def set(keys:, values:)
          keys.map do |key|
            self.class.pack(hash: values).each do |k, c|
              d = @data.fetch(key.join(@separator), {})
              d[k] = c
              @data[key.join(@separator)] = d
            end
          end
        end

        def get(keys:)
          keys.map do |key|
            self.class.unpack(
              hash: @data.fetch(key.join(@separator), {})
            )
          end
        end

        def ping(*)
          []
        end

        def scan(*)
          []
        end
      end
    end
  end
end
