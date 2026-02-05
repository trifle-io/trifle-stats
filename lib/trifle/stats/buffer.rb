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
          pending_mutex.synchronize do
            pending.delete(buffer)
          end
        end

        def enqueue_pending(buffer)
          pending_mutex.synchronize do
            pending << buffer unless pending.include?(buffer)
          end
        end

        def cancel_pending(buffer)
          pending_mutex.synchronize do
            pending.delete(buffer)
          end
        end

        def run_pending!
          snapshot = pending_mutex.synchronize do
            buffers = pending.dup
            pending.clear
            buffers
          end
          snapshot.each(&:flush_from_registry!)
        end

        def pending?
          pending_mutex.synchronize { pending.any? }
        end

        def flush_all
          run_pending!
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

        def pending
          @pending ||= []
        end

        def pending_mutex
          @pending_mutex ||= Mutex.new
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

      def store(operation, keys, values, tracking_key)
        if aggregate?
          store_aggregate(operation, keys, values, tracking_key)
        else
          store_linear(operation, keys, values, tracking_key)
        end
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

      def store_linear(operation, keys, values, tracking_key)
        @actions << build_action(operation, keys, values, tracking_key)
      end

      def store_aggregate(operation, keys, values, tracking_key)
        signature = signature_for(operation, keys, tracking_key)
        if (entry = @actions[signature])
          entry[:values] = merge_values(operation, entry[:values], values)
          entry[:count] += 1
        else
          @actions[signature] = build_action(operation, keys, values, tracking_key)
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

      def signature_for(operation, keys, tracking_key)
        tracking_marker = tracking_key || '__tracked__'
        identifiers = keys.map do |key|
          [key.prefix, key.key, key.granularity, key.at&.to_i].join(':')
        end
        "#{operation}-#{tracking_marker}-#{identifiers.join('|')}"
      end

      def build_action(operation, keys, values, tracking_key)
        {
          operation: operation,
          keys: keys,
          values: duplicate(values),
          count: 1,
          tracking_key: tracking_key
        }
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

    class Buffer # rubocop:disable Metrics/ClassLength
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

        def run_pending!
          BufferRegistry.run_pending!
        end

        def pending_flushes?
          BufferRegistry.pending?
        end
      end

      def initialize(driver:, duration: DEFAULT_DURATION, size: DEFAULT_SIZE, aggregate: true, async: true) # rubocop:disable Metrics/MethodLength
        @driver = driver
        @duration = duration.to_f
        @size = size.to_i.positive? ? size.to_i : 1
        @async = async
        @queue = BufferQueue.new(aggregate: aggregate)
        @mutex = Mutex.new
        @stopped = false
        @flush_pending = false
        @pending_condition = ConditionVariable.new
        @worker = start_worker if async && @duration.positive?
        self.class.register(self)
      end

      def inc(keys:, values:, tracking_key: nil)
        enqueue(:inc, keys: keys, values: values, tracking_key: tracking_key)
      end

      def set(keys:, values:, tracking_key: nil)
        enqueue(:set, keys: keys, values: values, tracking_key: tracking_key)
      end

      def flush!
        actions = drain_actions(reset_pending: true)
        return if actions.nil?

        process(actions)
      end

      def shutdown!
        return if @shutdown

        @shutdown = true
        stop_worker
        BufferRegistry.cancel_pending(self)
        flush!
        self.class.unregister(self)
      end

      def flush_from_registry!
        actions = drain_pending_actions
        process(actions) if actions
      end

      private

      def enqueue(operation, keys:, values:, tracking_key:)
        should_flush = false
        @mutex.synchronize do
          @queue.store(operation, keys, values, tracking_key)
          should_flush = @queue.size >= @size
        end

        flush! if should_flush
      end

      def request_async_flush
        return unless mark_flush_pending

        BufferRegistry.enqueue_pending(self)
        wait_for_pending_flush
      end

      def mark_flush_pending
        @mutex.synchronize do
          return false if @queue.empty? || @flush_pending

          @flush_pending = true
          true
        end
      end

      def drain_actions(reset_pending: false)
        @mutex.synchronize do
          return if @queue.empty?

          mark_flush_serviced if reset_pending
          @queue.drain
        end
      end

      def drain_pending_actions
        @mutex.synchronize do
          return unless @flush_pending
          return if @queue.empty?

          mark_flush_serviced
          @queue.drain
        end
      end

      def wait_for_pending_flush # rubocop:disable Metrics/MethodLength
        should_force = false
        timeout = @duration.positive? ? @duration : DEFAULT_DURATION
        @mutex.synchronize do
          while @flush_pending && timeout.positive?
            @pending_condition.wait(@mutex, timeout)
            break unless @flush_pending

            timeout = 0
          end
          should_force = @flush_pending
        end

        return unless should_force

        BufferRegistry.cancel_pending(self)
        flush!
      end

      def mark_flush_serviced
        return unless @flush_pending

        @flush_pending = false
        BufferRegistry.cancel_pending(self)
        @pending_condition.broadcast
      end

      def process(actions)
        actions.each { |action| dispatch_action(action) }
      ensure
        release_active_record_connection
      end

      def dispatch_action(action)
        payload = action_payload(action)

        if action[:tracking_key]
          @driver.public_send(action[:operation], **payload.merge(tracking_key: action[:tracking_key]))
        else
          @driver.public_send(action[:operation], **payload)
        end
      end

      def action_payload(action)
        {
          keys: action[:keys],
          values: action[:values],
          count: action[:count] || 1
        }
      end

      def start_worker
        Thread.new do
          loop do
            break if @stopped

            sleep(@duration)
            request_async_flush
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
