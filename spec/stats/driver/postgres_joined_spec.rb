require 'pg'

RSpec.describe Trifle::Stats::Driver::Postgres do
  let(:pg_client) { PG.connect(ENV.fetch('DATABASE_URL', 'postgresql://postgres:password@postgres:5432/postgres')) }
  let(:driver) { described_class.new(pg_client, table_name: 'test_stats') }

  before(:each) do
    pg_client.exec('DROP TABLE IF EXISTS test_stats')
    described_class.setup!(pg_client, table_name: 'test_stats')
  end

  after(:each) do
    pg_client.exec('DELETE FROM test_stats')
  end

  after(:all) do
    client = PG.connect(ENV.fetch('DATABASE_URL', 'postgresql://postgres:password@postgres:5432/postgres'))
    client.exec('DROP TABLE IF EXISTS test_stats')
    client.close
  end

  describe '#initialize' do
    it 'sets client, table_name and separator' do
      driver = described_class.new(pg_client, table_name: 'custom_stats')
      
      expect(driver.client).to eq(pg_client)
      expect(driver.table_name).to eq('custom_stats')
      expect(driver.separator).to eq('::')
    end

    it 'uses default table_name when not provided' do
      driver = described_class.new(pg_client)
      
      expect(driver.table_name).to eq('trifle_stats')
    end
  end

  describe '.setup!' do
    let(:test_table) { 'temp_test_table' }

    before do
      pg_client.exec("DROP TABLE IF EXISTS #{test_table}")
    end

    after do
      pg_client.exec("DROP TABLE IF EXISTS #{test_table}")
    end

    it 'creates table with correct structure' do
      described_class.setup!(pg_client, table_name: test_table)

      result = pg_client.exec("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '#{test_table}' ORDER BY ordinal_position")
      columns = result.map { |row| [row['column_name'], row['data_type']] }

      expect(columns).to eq([
        ['key', 'character varying'],
        ['data', 'jsonb']
      ])
    end
  end

  describe '#inc' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-02-01'))
      ]
    end
    let(:values) { { count: 5, duration: 100 } }

    it 'increments values for each key' do
      driver.inc(keys: keys, values: values)

      # Get actual keys from database
      key1 = keys[0].join('::')
      key2 = keys[1].join('::')
      result1 = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key1}'").first
      result2 = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key2}'").first

      expect(JSON.parse(result1['data'])).to eq({'count' => 5, 'duration' => 100})
      expect(JSON.parse(result2['data'])).to eq({'count' => 5, 'duration' => 100})
    end

    it 'increments existing values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_str = key.join('::')
      pg_client.exec("INSERT INTO test_stats (key, data) VALUES ('#{key_str}', '{\"count\": 10}')")
      
      driver.inc(keys: [key], values: { count: 5 })

      result = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key_str}'").first
      expect(JSON.parse(result['data'])['count']).to eq(15)
    end

    it 'handles nested values using packer' do
      nested_values = { stats: { requests: 10, errors: 2 } }
      
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_str = key.join('::')
      driver.inc(keys: [key], values: nested_values)

      result = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key_str}'").first
      expect(JSON.parse(result['data'])).to eq({
        'stats.requests' => 10,
        'stats.errors' => 2
      })
    end
  end

  describe '#set' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-02-01'))
      ]
    end
    let(:values) { { count: 10, status: 'active' } }

    it 'sets values for each key' do
      driver.set(keys: keys, values: values)

      key1 = keys[0].join('::')
      key2 = keys[1].join('::')
      result1 = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key1}'").first
      result2 = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key2}'").first

      expect(JSON.parse(result1['data'])).to eq({'count' => 10, 'status' => 'active'})
      expect(JSON.parse(result2['data'])).to eq({'count' => 10, 'status' => 'active'})
    end

    it 'overwrites existing values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_str = key.join('::')
      pg_client.exec("INSERT INTO test_stats (key, data) VALUES ('#{key_str}', '{\"count\": 100}')")
      
      driver.set(keys: [key], values: { count: 10 })

      result = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key_str}'").first
      expect(JSON.parse(result['data'])['count']).to eq(10)
    end

    it 'handles nested values using packer' do
      nested_values = { config: { enabled: true, limit: 50 } }
      
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_str = key.join('::')
      driver.set(keys: [key], values: nested_values)

      result = pg_client.exec("SELECT data FROM test_stats WHERE key = '#{key_str}'").first
      expect(JSON.parse(result['data'])).to eq({
        'config.enabled' => true,
        'config.limit' => 50
      })
    end
  end

  describe '#get' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-02-01'))
      ]
    end

    it 'retrieves values for each key' do
      key1 = keys[0].join('::')
      key2 = keys[1].join('::')
      pg_client.exec("INSERT INTO test_stats (key, data) VALUES ('#{key1}', '{\"count\": 10, \"status\": \"active\"}')")
      pg_client.exec("INSERT INTO test_stats (key, data) VALUES ('#{key2}', '{\"count\": 5}')")

      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10, 'status' => 'active'},
        {'count' => 5}
      ])
    end

    it 'unpacks nested values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_str = key.join('::')
      pg_client.exec("INSERT INTO test_stats (key, data) VALUES ('#{key_str}', '{\"stats.requests\": 100, \"stats.errors\": 5, \"simple\": 42}')")

      result = driver.get(keys: [key])

      expect(result).to eq([{
        'stats' => {'requests' => 100, 'errors' => 5},
        'simple' => 42
      }])
    end

    it 'handles empty results' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      result = driver.get(keys: [key])

      expect(result).to eq([{}])
    end

    it 'handles multiple keys with mixed data' do
      keys = [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-02-01'))
      ]
      key1 = keys[0].join('::')
      pg_client.exec("INSERT INTO test_stats (key, data) VALUES ('#{key1}', '{\"count\": 10}')")
      
      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10},
        {}
      ])
    end

    it 'handles empty JSON objects' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_str = key.join('::')
      pg_client.exec("INSERT INTO test_stats (key, data) VALUES ('#{key_str}', '{}')")

      result = driver.get(keys: [key])

      expect(result).to eq([{}])
    end
  end
end