# frozen_string_literal: true

require_relative '../mixins/packer'

module Trifle
  module Stats
    module Driver
      class Mongo # rubocop:disable Metrics/ClassLength
        include Mixins::Packer
        attr_accessor :client, :collection_name

        def initialize(client, collection_name: 'trifle_stats', joined_identifier: :full, expire_after: nil, system_tracking: true, bulk_write: true) # rubocop:disable Layout/LineLength, Metrics/ParameterLists
          @client = client
          @collection_name = collection_name
          @joined_identifier = self.class.normalize_joined_identifier(joined_identifier)
          @expire_after = expire_after
          @system_tracking = system_tracking
          @bulk_write = bulk_write
          @separator = '::'
        end

        def self.setup!(client, collection_name: 'trifle_stats', joined_identifier: :full, expire_after: nil) # rubocop:disable Metrics/MethodLength
          collection = client[collection_name]
          collection.create
          identifier_mode = normalize_joined_identifier(joined_identifier)
          case identifier_mode
          when :full
            collection.indexes.create_one({ key: 1 }, unique: true)
          when :partial
            collection.indexes.create_one({ key: 1, at: -1 }, unique: true)
          else
            collection.indexes.create_one({ key: 1, granularity: 1, at: -1 }, unique: true)
          end
          collection.indexes.create_one({ expire_at: 1 }, expire_after_seconds: 0) if expire_after
        end

        def description
          mode = if @joined_identifier == :full
                   'J'
                 else
                   @joined_identifier == :partial ? 'P' : 'S'
                 end
          "#{self.class.name}(#{mode})"
        end

        attr_reader :separator

        def system_identifier_for(key:)
          key = Nocturnal::Key.new(key: '__system__key__', granularity: key.granularity, at: key.at)
          identifier_for(key)
        end

        def system_data_for(key:, count: 1)
          self.class.pack(hash: { data: { count: count, keys: { key.key => count } } })
        end

        def inc(keys:, values:, count: 1) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          data = self.class.pack(hash: { data: values })

          if @bulk_write
            operations = keys.each_with_object([]) do |key, ops|
              filter = identifier_for(key)
              expire_at = @expire_after ? key.at + @expire_after : nil

              ops << upsert_operation('$inc', filter: filter, data: data, expire_at: expire_at)
              ops << upsert_operation('$inc', filter: system_identifier_for(key: key), data: system_data_for(key: key, count: count), expire_at: expire_at) if @system_tracking # rubocop:disable Layout/LineLength
            end

            collection.bulk_write(operations)
          else
            keys.each do |key|
              filter = identifier_for(key)
              expire_at = @expire_after ? key.at + @expire_after : nil
              update = build_update('$inc', data: data, expire_at: expire_at)

              collection.update_many(filter, update, upsert: true)
              collection.update_many(system_identifier_for(key: key), build_update('$inc', data: system_data_for(key: key, count: count), expire_at: expire_at), upsert: true) if @system_tracking # rubocop:disable Layout/LineLength
            end
          end
        end

        def set(keys:, values:, count: 1) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          data = self.class.pack(hash: { data: values })

          if @bulk_write
            operations = keys.each_with_object([]) do |key, ops|
              filter = identifier_for(key)
              expire_at = @expire_after ? key.at + @expire_after : nil

              ops << upsert_operation('$set', filter: filter, data: data, expire_at: expire_at)
              ops << upsert_operation('$inc', filter: system_identifier_for(key: key), data: system_data_for(key: key, count: count), expire_at: expire_at) if @system_tracking # rubocop:disable Layout/LineLength
            end

            collection.bulk_write(operations)
          else
            keys.each do |key|
              filter = identifier_for(key)
              expire_at = @expire_after ? key.at + @expire_after : nil
              update = build_update('$set', data: data, expire_at: expire_at)

              collection.update_many(filter, update, upsert: true)
              collection.update_many(system_identifier_for(key: key), build_update('$inc', data: system_data_for(key: key, count: count), expire_at: expire_at), upsert: true) if @system_tracking # rubocop:disable Layout/LineLength
            end
          end
        end

        def ping(key:, values:) # rubocop:disable Metrics/MethodLength
          return [] if @joined_identifier

          data = self.class.pack(hash: { data: values, at: key.at })
          identifier = identifier_for(key)
          expire_at = @expire_after ? key.at + @expire_after : nil

          if @bulk_write
            operations = [
              upsert_operation('$set', filter: identifier.slice(:key), data: data, expire_at: expire_at)
            ]

            collection.bulk_write(operations)
          else
            update = build_update('$set', data: data, expire_at: expire_at)
            collection.update_many(identifier.slice(:key), update, upsert: true)
          end
        end

        def upsert_operation(operation, filter:, data:, expire_at: nil)
          update = build_update(operation, data: data, expire_at: expire_at)
          { update_many: { filter: filter, update: update, upsert: true } }
        end

        def build_update(operation, data:, expire_at: nil)
          # Merge if $set and $set
          update_data = operation == '$set' && expire_at ? data.merge(expire_at: expire_at) : data

          # Add if $inc and $set
          {
            operation => update_data,
            **(operation != '$set' && expire_at ? { '$set' => { expire_at: expire_at } } : {})
          }
        end

        def get(keys:) # rubocop:disable Metrics/AbcSize
          combinations = keys.map { |key| identifier_for(key) }
          data = collection.find('$or' => combinations)
          map = data.inject({}) do |o, d|
            o.merge(
              Nocturnal::Key.new(
                key: d['key'], granularity: d['granularity'], at: d['at']
              ).identifier(separator, @joined_identifier) => d['data']
            )
          end

          combinations.map { |combination| map[combination] || {} }
        end

        def scan(key:)
          return [] if @joined_identifier

          data = collection.find(
            **identifier_for(key)
          ).sort(at: -1).first # rubocop:disable Style/RedundantSort
          return [] if data.nil?

          [data['at'], data['data']]
        end

        def self.normalize_joined_identifier(value)
          case value
          when nil, :full, 'full', :partial, 'partial'
            value.nil? ? nil : value.to_sym
          else
            raise ArgumentError, 'joined_identifier must be nil, :full, "full", :partial, or "partial"'
          end
        end

        private

        def identifier_for(key)
          key.identifier(separator, @joined_identifier)
        end

        def collection
          client[collection_name]
        end
      end
    end
  end
end
