require 'redis'

RSpec.describe Trifle::Stats::Driver::Redis do
  let(:redis_client) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/15')) }
  let(:driver) { described_class.new(redis_client, prefix: 'test') }

  before(:each) do
    redis_client.flushdb
  end

  after(:all) do
    client = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/15'))
    client.flushdb
    client.close
  end

  describe '#initialize' do
    it 'sets client, prefix and separator' do
      driver = described_class.new(redis_client, prefix: 'custom')
      
      expect(driver.client).to eq(redis_client)
      expect(driver.prefix).to eq('custom')
      expect(driver.separator).to eq('::')
    end

    it 'uses default prefix when not provided' do
      driver = described_class.new(redis_client)
      
      expect(driver.prefix).to eq('trfl')
    end
  end

  describe '#inc' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 2)
      ]
    end
    let(:values) { { count: 5, duration: 100 } }

    it 'increments values for each key' do
      driver.inc(keys: keys, values: values)

      result1 = redis_client.hgetall('test::metric::2023::1')
      result2 = redis_client.hgetall('test::metric::2023::2')

      expect(result1).to eq({'count' => '5', 'duration' => '100'})
      expect(result2).to eq({'count' => '5', 'duration' => '100'})
    end

    it 'increments existing values' do
      redis_client.hset('test::metric::2023::1', 'count', '10')
      
      driver.inc(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1)], values: { count: 5 })

      result = redis_client.hgetall('test::metric::2023::1')
      expect(result['count']).to eq('15')
    end

    it 'handles nested values using packer' do
      nested_values = { stats: { requests: 10, errors: 2 } }
      
      driver.inc(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1)], values: nested_values)

      result = redis_client.hgetall('test::metric::2023::1')
      expect(result).to eq({
        'stats.requests' => '10',
        'stats.errors' => '2'
      })
    end
  end

  describe '#set' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 2)
      ]
    end
    let(:values) { { count: 10, status: 'active' } }

    it 'sets values for each key' do
      driver.set(keys: keys, values: values)

      result1 = redis_client.hgetall('test::metric::2023::1')
      result2 = redis_client.hgetall('test::metric::2023::2')

      expect(result1).to eq({'count' => '10', 'status' => 'active'})
      expect(result2).to eq({'count' => '10', 'status' => 'active'})
    end

    it 'overwrites existing values' do
      redis_client.hset('test::metric::2023::1', 'count', '100')
      
      driver.set(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1)], values: { count: 10 })

      result = redis_client.hgetall('test::metric::2023::1')
      expect(result['count']).to eq('10')
    end

    it 'handles nested values using packer' do
      nested_values = { config: { enabled: true, limit: 50 } }
      
      driver.set(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1)], values: nested_values)

      result = redis_client.hgetall('test::metric::2023::1')
      expect(result).to eq({
        'config.enabled' => 'true',
        'config.limit' => '50'
      })
    end
  end

  describe '#get' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 2)
      ]
    end

    it 'retrieves values for each key' do
      redis_client.hset('test::metric::2023::1', 'count', '10', 'status', 'active')
      redis_client.hset('test::metric::2023::2', 'count', '5')

      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => '10', 'status' => 'active'},
        {'count' => '5'}
      ])
    end

    it 'unpacks nested values' do
      redis_client.hset('test::metric::2023::1', 
        'stats.requests', '100',
        'stats.errors', '5',
        'simple', '42'
      )

      result = driver.get(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1)])

      expect(result).to eq([{
        'stats' => {'requests' => '100', 'errors' => '5'},
        'simple' => '42'
      }])
    end

    it 'handles empty results' do
      result = driver.get(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1)])

      expect(result).to eq([{}])
    end

    it 'handles multiple keys with mixed data' do
      redis_client.hset('test::metric::2023::1', 'count', '10')
      
      result = driver.get(keys: [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: 2023, at: 2)
      ])

      expect(result).to eq([
        {'count' => '10'},
        {}
      ])
    end
  end
end