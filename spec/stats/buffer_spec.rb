require 'time'

RSpec.describe Trifle::Stats::Buffer do
  let(:driver) { instance_double(Trifle::Stats::Driver::Process) }
  let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '1h', at: Time.parse('2023-01-01 12:00:00 UTC')) }

  describe '#inc and #flush!' do
    it 'flushes when queue reaches configured size' do
      buffer = described_class.new(driver: driver, duration: 60, size: 2, aggregate: false, async: false)
      allow(driver).to receive(:inc)

      buffer.inc(keys: [key], values: { count: 1 })
      buffer.inc(keys: [key], values: { count: 2 })

      expect(driver).to have_received(:inc).twice
      buffer.shutdown!
    end

    it 'flushes aggregated queue when action count reaches size' do
      buffer = described_class.new(driver: driver, duration: 60, size: 2, aggregate: true, async: false)
      counts = []
      allow(driver).to receive(:inc) do |args|
        counts << args[:values][:count]
      end

      4.times { buffer.inc(keys: [key], values: { count: 1 }) }
      buffer.shutdown!

      expect(driver).to have_received(:inc).twice
      expect(counts).to eq([2, 2])
    end

    it 'aggregates increments for identical keys' do
      buffer = described_class.new(driver: driver, duration: 60, size: 10, aggregate: true, async: false)

      expect(driver).to receive(:inc).with(
        keys: [key],
        values: { count: 3, nested: { requests: 4 } }
      )

      buffer.inc(keys: [key], values: { count: 1, nested: { requests: 1 } })
      buffer.inc(keys: [key], values: { count: 2, nested: { requests: 3 } })
      buffer.flush!
      buffer.shutdown!
    end

    it 'aggregates set operations by keeping last write' do
      buffer = described_class.new(driver: driver, duration: 60, size: 10, aggregate: true, async: false)

      expect(driver).to receive(:set).with(
        keys: [key],
        values: { state: 'done', detail: { attempts: 3 } }
      )

      buffer.set(keys: [key], values: { state: 'processing' })
      buffer.set(keys: [key], values: { state: 'done', detail: { attempts: 3 } })
      buffer.flush!
      buffer.shutdown!
    end
  end

  describe 'time based flushing' do
    it 'flushes automatically after configured duration once pending work is processed' do
      buffer = described_class.new(driver: driver, duration: 0.1, size: 10, aggregate: false, async: true)
      allow(driver).to receive(:inc)

      buffer.inc(keys: [key], values: { count: 1 })
      sleep(0.12)
      expect(driver).not_to have_received(:inc)

      described_class.run_pending!
      buffer.shutdown!

      expect(driver).to have_received(:inc).once
    end

    it 'falls back to flushing on ticker thread when pending work is ignored' do
      buffer = described_class.new(driver: driver, duration: 0.05, size: 10, aggregate: false, async: true)
      allow(driver).to receive(:inc)

      buffer.inc(keys: [key], values: { count: 3 })
      sleep(0.2)

      buffer.shutdown!

      expect(driver).to have_received(:inc).once
    end
  end

  describe '#shutdown!' do
    it 'flushes outstanding operations when shutting down' do
      buffer = described_class.new(driver: driver, duration: 60, size: 10, aggregate: false, async: false)

      expect(driver).to receive(:inc).with(keys: [key], values: { count: 5 })
      buffer.inc(keys: [key], values: { count: 5 })

      buffer.shutdown!
    end
  end
end
