require 'sqlite3'
require 'time'

RSpec.describe Trifle::Stats::Driver::Sqlite do
  let(:sqlite_client) { SQLite3::Database.new(':memory:') }
  let(:driver) { described_class.new(sqlite_client, table_name: 'test_stats_separated', joined_identifier: false) }

  before(:each) do
    sqlite_client.execute('DROP TABLE IF EXISTS test_stats_separated')
    sqlite_client.execute('DROP TABLE IF EXISTS test_stats_separated_ping')
    described_class.setup!(sqlite_client, table_name: 'test_stats_separated', joined_identifier: false)
  end

  after(:each) do
    sqlite_client.execute('DELETE FROM test_stats_separated')
  end

  describe '#initialize' do
    it 'sets client, table_name and separator' do
      driver = described_class.new(sqlite_client, table_name: 'custom_stats', joined_identifier: false)
      
      expect(driver.client).to eq(sqlite_client)
      expect(driver.table_name).to eq('custom_stats')
      expect(driver.separator).to be_nil
    end

    it 'uses default table_name when not provided' do
      driver = described_class.new(sqlite_client, joined_identifier: false)
      
      expect(driver.table_name).to eq('trifle_stats')
    end
  end

  describe '.setup!' do
    let(:test_table) { 'temp_test_table_separated' }

    before do
      sqlite_client.execute("DROP TABLE IF EXISTS #{test_table}")
    end

    after do
      sqlite_client.execute("DROP TABLE IF EXISTS #{test_table}")
    end

    it 'creates table with correct structure' do
      described_class.setup!(sqlite_client, table_name: test_table, joined_identifier: false)

      result = sqlite_client.execute("PRAGMA table_info(#{test_table})")
      columns = result.map { |row| [row[1], row[2]] } # name, type

      expect(columns).to eq([
        ['key', 'varchar(255)'],
        ['range', 'varchar(255)'],
        ['at', 'datetime'],
        ['data', 'json']
      ])
    end

    it 'creates unique composite index' do
      described_class.setup!(sqlite_client, table_name: test_table, joined_identifier: false)

      result = sqlite_client.execute("PRAGMA index_list(#{test_table})")
      unique_indexes = result.select { |row| row[2] == 1 }

      expect(unique_indexes).not_to be_empty
    end
  end

  describe '#inc' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-02-01'))
      ]
    end
    let(:values) { { count: 5, duration: 100 } }

    it 'increments values for each key' do
      driver.inc(keys: keys, **values)

      key1_at = keys[0].at.strftime('%Y-%m-%d %H:%M:%S')
      key2_at = keys[1].at.strftime('%Y-%m-%d %H:%M:%S')
      result1 = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key1_at}'").first
      result2 = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key2_at}'").first

      expect(JSON.parse(result1[0])).to eq({'count' => 5, 'duration' => 100})
      expect(JSON.parse(result2[0])).to eq({'count' => 5, 'duration' => 100})
    end

    it 'increments existing values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.strftime('%Y-%m-%d %H:%M:%S')
      sqlite_client.execute("INSERT INTO test_stats_separated (key, range, at, data) VALUES ('metric', '2023', '#{key_at}', json('{\"count\": 10}'))")
      
      driver.inc(keys: [key], count: 5)

      result = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key_at}'").first
      expect(JSON.parse(result[0])['count']).to eq(15)
    end

    it 'handles nested values using packer' do
      nested_values = { stats: { requests: 10, errors: 2 } }
      
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.strftime('%Y-%m-%d %H:%M:%S')
      driver.inc(keys: [key], **nested_values)

      result = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key_at}'").first
      expect(JSON.parse(result[0])).to eq({
        'stats.requests' => 10,
        'stats.errors' => 2
      })
    end
  end

  describe '#set' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-02-01'))
      ]
    end
    let(:values) { { count: 10, status: 'active' } }

    it 'sets values for each key' do
      driver.set(keys: keys, **values)

      key1_at = keys[0].at.strftime('%Y-%m-%d %H:%M:%S')
      key2_at = keys[1].at.strftime('%Y-%m-%d %H:%M:%S')
      result1 = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key1_at}'").first
      result2 = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key2_at}'").first

      expect(JSON.parse(result1[0])).to eq({'count' => 10, 'status' => 'active'})
      expect(JSON.parse(result2[0])).to eq({'count' => 10, 'status' => 'active'})
    end

    it 'overwrites existing values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.strftime('%Y-%m-%d %H:%M:%S')
      sqlite_client.execute("INSERT INTO test_stats_separated (key, range, at, data) VALUES ('metric', '2023', '#{key_at}', json('{\"count\": 100}'))")
      
      driver.set(keys: [key], count: 10)

      result = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key_at}'").first
      expect(JSON.parse(result[0])['count']).to eq(10)
    end

    it 'handles nested values using packer' do
      nested_values = { config: { enabled: true, limit: 50 } }
      
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.strftime('%Y-%m-%d %H:%M:%S')
      driver.set(keys: [key], **nested_values)

      result = sqlite_client.execute("SELECT data FROM test_stats_separated WHERE key = 'metric' AND range = '2023' AND at = '#{key_at}'").first
      expect(JSON.parse(result[0])).to eq({
        'config.enabled' => true,
        'config.limit' => 50
      })
    end
  end

  describe '#get' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-02-01'))
      ]
    end

    it 'retrieves values for each key' do
      driver.inc(keys: [keys[0]], count: 10)
      driver.inc(keys: [keys[1]], count: 5)

      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10},
        {'count' => 5}
      ])
    end

    it 'unpacks nested values' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      nested_values = { stats: { requests: 100, errors: 5 }, simple: 42 }
      driver.inc(keys: [key], **nested_values)

      result = driver.get(keys: [key])

      expect(result).to eq([{
        'stats' => {'requests' => 100, 'errors' => 5},
        'simple' => 42
      }])
    end

    it 'handles empty results' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      result = driver.get(keys: [key])

      expect(result).to eq([{}])
    end

    it 'handles multiple keys with mixed data' do
      keys = [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01')),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-02-01'))
      ]
      driver.inc(keys: [keys[0]], count: 10)
      
      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10},
        {}
      ])
    end

    it 'handles invalid JSON gracefully' do
      key = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      key_at = key.at.strftime('%Y-%m-%d %H:%M:%S')
      sqlite_client.execute("INSERT INTO test_stats_separated (key, range, at, data) VALUES ('metric', '2023', '#{key_at}', 'invalid_json')")

      result = driver.get(keys: [key])

      expect(result).to eq([{}])
    end
  end

  describe '#scan' do
    let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01')) }

    it 'returns latest data for key' do
      key1 = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01'))
      key2 = Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-02'))
      driver.ping(key: key1, count: 10)
      driver.ping(key: key2, count: 20)
      
      result = driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'metric'))

      expect(result[0]).to be_a(Time)
      expect(result[1]).to eq({ 'data' => { 'count' => 20 }, 'at' => "2023-01-02 00:00:00 +0100" })
    end

    it 'returns empty array when no data found' do
      result = driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'nonexistent'))

      expect(result).to eq([])
    end
  end

  describe '#ping' do
    let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: '2023', at: Time.parse('2023-01-01')) }
    let(:values) { { status: 'active', count: 1 } }

    it 'stores ping data' do
      driver.ping(key: key, **values)

      result = sqlite_client.execute("SELECT data FROM test_stats_separated_ping WHERE key = 'metric'").first
      data = JSON.parse(result[0])
      expect(data['data.status']).to eq('active')
      expect(data['data.count']).to eq(1)
    end
  end
end