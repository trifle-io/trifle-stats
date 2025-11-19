# frozen_string_literal: true

module Trifle
  module Stats
    module BufferRegistry
      class << self
        def register(buffer)
          registry_mutex.synchronize do
            registry << buffer
            install_shutdown_hooks
          end
        end

        def unregister(buffer)
          registry_mutex.synchronize do
            registry.delete(buffer)
          end
        end

        def flush_all
          snapshot = registry_mutex.synchronize { registry.dup }
          snapshot.each(&:shutdown!)
        end

        private

        def registry
          @registry ||= []
        end

        def registry_mutex
          @registry_mutex ||= Mutex.new
        end

        def install_shutdown_hooks
          return if @shutdown_hooks_installed

          at_exit { flush_all }
          install_sigterm_trap if Signal.list.key?('TERM')
          @shutdown_hooks_installed = true
        end

        def install_sigterm_trap
          previous = Signal.trap('TERM') do
            flush_all
            invoke_previous_handler(previous)
          end
          @previous_sigterm_handler = previous
        end

        def invoke_previous_handler(previous)
          case previous
          when Proc
            previous.call
          when Symbol, String
            Signal.trap('TERM', previous)
            Process.kill('TERM', Process.pid)
          end
        rescue StandardError
          nil
        end
      end
    end

    class BufferQueue
      def initialize(aggregate:)
        @aggregate = aggregate
        reset!
      end

      def store(operation, keys, values)
        aggregate? ? store_aggregate(operation, keys, values) : store_linear(operation, keys, values)
        @operation_count += 1
      end

      def size
        @operation_count
      end

      def empty?
        size.zero?
      end

      def drain
        drained = aggregate? ? @actions.values : @actions.dup
        reset!
        drained
      end

      private

      def aggregate?
        @aggregate
      end

      def reset!
        @actions = aggregate? ? {} : []
        @operation_count = 0
      end

      def store_linear(operation, keys, values)
        @actions << { operation: operation, keys: keys, values: duplicate(values) }
      end

      def store_aggregate(operation, keys, values)
        signature = signature_for(operation, keys)
        if (entry = @actions[signature])
          entry[:values] = merge_values(operation, entry[:values], values)
        else
          @actions[signature] = { operation: operation, keys: keys, values: duplicate(values) }
        end
      end

      def merge_values(operation, current, incoming)
        case operation
        when :inc
          merge_increment(current, incoming)
        when :set
          duplicate(incoming)
        else
          duplicate(incoming)
        end
      end

      def merge_increment(current, incoming)
        incoming.each do |key, value|
          current[key] =
            if value.is_a?(Hash)
              merge_increment(current.fetch(key, {}), value)
            else
              current.fetch(key, 0).to_i + value.to_i
            end
        end
        current
      end

      def signature_for(operation, keys)
        identifiers = keys.map do |key|
          [key.prefix, key.key, key.granularity, key.at&.to_i].join(':')
        end
        "#{operation}-#{identifiers.join('|')}"
      end

      def duplicate(value)
        case value
        when Hash
          value.transform_values { |entry| duplicate(entry) }
        when Array
          value.map { |entry| duplicate(entry) }
        else
          value
        end
      end
    end

    class Buffer
      DEFAULT_DURATION = 1
      DEFAULT_SIZE = 256

      class << self
        def register(buffer)
          BufferRegistry.register(buffer)
        end

        def unregister(buffer)
          BufferRegistry.unregister(buffer)
        end

        def flush_all
          BufferRegistry.flush_all
        end
      end

      def initialize(driver:, duration: DEFAULT_DURATION, size: DEFAULT_SIZE, aggregate: true, async: true)
        @driver = driver
        @duration = duration.to_f
        @size = size.to_i.positive? ? size.to_i : 1
        @async = async
        @queue = BufferQueue.new(aggregate: aggregate)
        @mutex = Mutex.new
        @stopped = false
        @worker = start_worker if async && @duration.positive?
        self.class.register(self)
      end

      def inc(keys:, values:)
        enqueue(:inc, keys: keys, values: values)
      end

      def set(keys:, values:)
        enqueue(:set, keys: keys, values: values)
      end

      def flush!
        actions = nil
        @mutex.synchronize do
          return if @queue.empty?

          actions = @queue.drain
        end

        process(actions)
      end

      def shutdown!
        return if @shutdown

        @shutdown = true
        stop_worker
        flush!
        self.class.unregister(self)
      end

      private

      def enqueue(operation, keys:, values:)
        should_flush = false
        @mutex.synchronize do
          @queue.store(operation, keys, values)
          should_flush = @queue.size >= @size
        end

        flush! if should_flush
      end

      def process(actions)
        actions.each do |action|
          @driver.public_send(action[:operation], keys: action[:keys], values: action[:values])
        end
      ensure
        release_active_record_connection
      end

      def start_worker
        Thread.new do
          loop do
            break if @stopped

            sleep(@duration)
            flush!
          end
        end
      end

      def stop_worker
        return if @worker.nil?

        @stopped = true
        begin
          @worker.wakeup
        rescue ThreadError
          nil
        end
        @worker.join
      end

      def release_active_record_connection
        # Workers run on dedicated threads, so make sure ActiveRecord connections
        # are released back to the shared pool once a flush finishes.
        return unless defined?(::ActiveRecord::Base)

        ::ActiveRecord::Base.clear_active_connections!
      end
    end
  end
end
