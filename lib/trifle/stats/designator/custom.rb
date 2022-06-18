# frozen_string_literal: true

module Trifle
  module Stats
    class Designator
      class Custom
        attr_reader :buckets

        def initialize(buckets:)
          @buckets = buckets.sort
        end

        def designate(value:)
          return buckets.first.to_s if value <= buckets.first
          return "#{buckets.last}+" if value > buckets.last

          (buckets.find { |b| value.ceil < b }).to_s
        end
      end
    end
  end
end
