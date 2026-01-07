require 'pg'
require 'time'

RSpec.describe Trifle::Stats::Driver::Postgres do
  let(:pg_client) { PG.connect(ENV.fetch('DATABASE_URL', 'postgresql://postgres:password@postgres:5432/postgres')) }
  let(:driver) { described_class.new(pg_client, table_name: 'test_stats_separated', joined_identifier: nil) }

  before(:each) do
    pg_client.exec('DROP TABLE IF EXISTS test_stats_separated')
    pg_client.exec('DROP TABLE IF EXISTS test_stats_separated_ping')
    described_class.setup!(pg_client, table_name: 'test_stats_separated', joined_identifier: nil)
  end

  after(:each) do
    pg_client.exec('DELETE FROM test_stats_separated')
  end

  after(:all) do
    client = PG.connect(ENV.fetch('DATABASE_URL', 'postgresql://postgres:password@postgres:5432/postgres'))
    client.exec('DROP TABLE IF EXISTS test_stats_separated')
    client.close
  end

  describe '#initialize' do
    it 'sets client, table_name and separator' do
      driver = described_class.new(pg_client, table_name: 'custom_stats', joined_identifier: nil)
      
      expect(driver.client).to eq(pg_client)
      expect(driver.table_name).to eq('custom_stats')
      expect(driver.separator).to eq('::')
    end

    it 'uses default table_name when not provided' do
      driver = described_class.new(pg_client, joined_identifier: nil)
      
      expect(driver.table_name).to eq('trifle_stats')
    end
  end

  describe '.setup!' do
    let(:test_table) { 'temp_test_table_separated' }

    before do
      pg_client.exec("DROP TABLE IF EXISTS #{test_table}")
      pg_client.exec("DROP TABLE IF EXISTS #{test_table}_ping")
    end

    after do
      pg_client.exec("DROP TABLE IF EXISTS #{test_table}")
      pg_client.exec("DROP TABLE IF EXISTS #{test_table}_ping")
    end

    it 'creates table with correct structure' do
      described_class.setup!(pg_client, table_name: test_table, joined_identifier: nil)

      result = pg_client.exec("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '#{test_table}' ORDER BY ordinal_position")
      columns = result.map { |row| [row['column_name'], row['data_type']] }

      expect(columns).to eq([
        ['key', 'character varying'],
        ['granularity', 'character varying'],
        ['at', 'timestamp with time zone'],
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
      key1_at = keys[0].at.iso8601
      key2_at = keys[1].at.iso8601
      result1 = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key1_at}'").first
      result2 = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key2_at}'").first

      expect(JSON.parse(result1['data'])).to eq({'count' => 5, 'duration' => 100})
      expect(JSON.parse(result2['data'])).to eq({'count' => 5, 'duration' => 100})
    end

    it 'increments existing values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.iso8601
      pg_client.exec("INSERT INTO test_stats_separated (key, granularity, at, data) VALUES ('metric', '2023', '#{key_at}', '{\"count\": 10}')")
      
      driver.inc(keys: [key], values: { count: 5 })

      result = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key_at}'").first
      expect(JSON.parse(result['data'])['count']).to eq(15)
    end

    it 'handles nested values using packer' do
      nested_values = { stats: { requests: 10, errors: 2 } }
      
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.iso8601
      driver.inc(keys: [key], values: nested_values)

      result = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key_at}'").first
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

      key1_at = keys[0].at.iso8601
      key2_at = keys[1].at.iso8601
      result1 = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key1_at}'").first
      result2 = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key2_at}'").first

      expect(JSON.parse(result1['data'])).to eq({'count' => 10, 'status' => 'active'})
      expect(JSON.parse(result2['data'])).to eq({'count' => 10, 'status' => 'active'})
    end

    it 'overwrites existing values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.iso8601
      pg_client.exec("INSERT INTO test_stats_separated (key, granularity, at, data) VALUES ('metric', '2023', '#{key_at}', '{\"count\": 100}')")
      
      driver.set(keys: [key], values: { count: 10 })

      result = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key_at}'").first
      expect(JSON.parse(result['data'])['count']).to eq(10)
    end

    it 'handles nested values using packer' do
      nested_values = { config: { enabled: true, limit: 50 } }
      
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.iso8601
      driver.set(keys: [key], values: nested_values)

      result = pg_client.exec("SELECT data FROM test_stats_separated WHERE key = 'metric' AND granularity = '2023' AND at = '#{key_at}'").first
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
      driver.inc(keys: [keys[0]], values: { count: 10 })
      driver.inc(keys: [keys[1]], values: { count: 5 })

      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10},
        {'count' => 5}
      ])
    end

    it 'unpacks nested values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      nested_values = { stats: { requests: 100, errors: 5 }, simple: 42 }
      driver.inc(keys: [key], values: nested_values)

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
      driver.inc(keys: [keys[0]], values: { count: 10 })
      
      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10},
        {}
      ])
    end

    it 'handles empty JSON objects' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.iso8601
      pg_client.exec("INSERT INTO test_stats_separated (key, granularity, at, data) VALUES ('metric', '2023', '#{key_at}', '{}')")

      result = driver.get(keys: [key])

      expect(result).to eq([{}])
    end
  end

  describe '#scan' do
    let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01')) }

    it 'returns latest data for key' do
      key1 = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01'))
      key2 = Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-02'))
      driver.ping(key: key1, values: { count: 10 })
      driver.ping(key: key2, values: { count: 20 })
      
      result = driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'metric'))

      expect(result[0]).to be_a(Time)
      expect(result[1]['data']).to eq({ 'count' => 20 })
      expect(result[1]['at']).to match(/2023-01-02 00:00:00 [+-]\d{4}/)
    end

    it 'returns empty array when no data found' do
      result = driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'nonexistent'))

      expect(result).to eq([])
    end
  end

  describe '#ping' do
    let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '2023', at: Time.parse('2023-01-01')) }
    let(:values) { { status: 'active', count: 1 } }

    it 'stores ping data' do
      driver.ping(key: key, values: values)

      result = pg_client.exec("SELECT data FROM test_stats_separated_ping WHERE key = 'metric'").first
      data = JSON.parse(result['data'])
      expect(data['data.status']).to eq('active')
      expect(data['data.count']).to eq(1)
    end
  end
end
