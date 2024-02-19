# frozen_string_literal: true

module Trifle
  module Stats
    module Mixins
      module Packer
        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          def pack(hash:, prefix: nil)
            hash.inject({}) do |o, (k, v)|
              key = [prefix, k].compact.join('.')
              if v.instance_of?(Hash)
                o.update(
                  pack(hash: v, prefix: key)
                )
              else
                o.update({ key => v })
              end
            end
          end

          def unpack(hash:)
            hash.inject({}) do |out, (key, v)|
              deep_merge(
                out,
                key.split('.').reverse.inject(v.to_f) { |o, k| { k => o } }
              )
            end
          end

          def deep_merge(this_hash, other_hash, &block)
            deep_merge!(this_hash.dup, other_hash, &block)
          end

          def deep_merge!(this_hash, other_hash, &block)
            this_hash.merge!(other_hash) do |key, this_val, other_val|
              if this_val.is_a?(Hash) && other_val.is_a?(Hash)
                deep_merge(this_val, other_val, &block)
              elsif block_given?
                block.call(key, this_val, other_val)
              else
                other_val
              end
            end
          end

          def normalize(object)
            case object
            when Hash
              object.each_with_object({}) do |(key, value), result|
                result[key.to_s] = normalize(value)
              end
            when Array
              object.map { |v| normalize(v) }
            else
              object
            end
          end
        end
      end
    end
  end
end
