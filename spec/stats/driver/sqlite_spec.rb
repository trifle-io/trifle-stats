require 'sqlite3'

RSpec.describe Trifle::Stats::Driver::Sqlite do
  let(:sqlite_client) { SQLite3::Database.new(':memory:') }
  let(:driver) { described_class.new(sqlite_client, table_name: 'test_stats') }

  before(:each) do
    described_class.setup!(sqlite_client, table_name: 'test_stats')
  end

  after(:each) do
    sqlite_client.execute('DELETE FROM test_stats')
  end

  after(:all) do
    client = SQLite3::Database.new(':memory:')
    client.close
  end

  describe '#initialize' do
    it 'sets client, table_name and separator' do
      driver = described_class.new(sqlite_client, table_name: 'custom_stats')
      
      expect(driver.client).to eq(sqlite_client)
      expect(driver.table_name).to eq('custom_stats')
      expect(driver.separator).to eq('::')
    end

    it 'uses default table_name when not provided' do
      driver = described_class.new(sqlite_client)
      
      expect(driver.table_name).to eq('trifle_stats')
    end
  end

  describe '.setup!' do
    let(:test_table) { 'temp_test_table' }

    before do
      sqlite_client.execute("DROP TABLE IF EXISTS #{test_table}")
    end

    after do
      sqlite_client.execute("DROP TABLE IF EXISTS #{test_table}")
    end

    it 'creates table with correct structure' do
      described_class.setup!(sqlite_client, table_name: test_table)

      result = sqlite_client.execute("PRAGMA table_info(#{test_table})")
      columns = result.map { |row| [row[1], row[2]] }

      expect(columns).to eq([
        ['key', 'varchar(255)'],
        ['data', 'json']
      ])
    end

    it 'creates unique index on key' do
      described_class.setup!(sqlite_client, table_name: test_table)

      result = sqlite_client.execute("PRAGMA index_list(#{test_table})")
      unique_indexes = result.select { |row| row[2] == 1 }

      expect(unique_indexes).not_to be_empty
    end
  end

  describe '#inc' do
    let(:keys) { [['metric', '2023', '01'], ['metric', '2023', '02']] }
    let(:values) { { count: 5, duration: 100 } }

    it 'increments values for each key' do
      driver.inc(keys: keys, **values)

      result1 = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::01'").first
      result2 = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::02'").first

      expect(JSON.parse(result1[0])).to eq({'count' => 5, 'duration' => 100})
      expect(JSON.parse(result2[0])).to eq({'count' => 5, 'duration' => 100})
    end

    it 'increments existing values' do
      sqlite_client.execute("INSERT INTO test_stats (key, data) VALUES ('metric::2023::01', json('{\"count\": 10}'))")
      
      driver.inc(keys: [['metric', '2023', '01']], count: 5)

      result = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::01'").first
      expect(JSON.parse(result[0])['count']).to eq(15)
    end

    it 'handles nested values using packer' do
      nested_values = { stats: { requests: 10, errors: 2 } }
      
      driver.inc(keys: [['metric', '2023', '01']], **nested_values)

      result = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::01'").first
      expect(JSON.parse(result[0])).to eq({
        'stats.requests' => 10,
        'stats.errors' => 2
      })
    end
  end

  describe '#set' do
    let(:keys) { [['metric', '2023', '01'], ['metric', '2023', '02']] }
    let(:values) { { count: 10, status: 'active' } }

    it 'sets values for each key' do
      driver.set(keys: keys, **values)

      result1 = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::01'").first
      result2 = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::02'").first

      expect(JSON.parse(result1[0])).to eq({'count' => 10, 'status' => 'active'})
      expect(JSON.parse(result2[0])).to eq({'count' => 10, 'status' => 'active'})
    end

    it 'overwrites existing values' do
      sqlite_client.execute("INSERT INTO test_stats (key, data) VALUES ('metric::2023::01', json('{\"count\": 100}'))")
      
      driver.set(keys: [['metric', '2023', '01']], count: 10)

      result = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::01'").first
      expect(JSON.parse(result[0])['count']).to eq(10)
    end

    it 'handles nested values using packer' do
      nested_values = { config: { enabled: true, limit: 50 } }
      
      driver.set(keys: [['metric', '2023', '01']], **nested_values)

      result = sqlite_client.execute("SELECT data FROM test_stats WHERE key = 'metric::2023::01'").first
      expect(JSON.parse(result[0])).to eq({
        'config.enabled' => true,
        'config.limit' => 50
      })
    end
  end

  describe '#get' do
    let(:keys) { [['metric', '2023', '01'], ['metric', '2023', '02']] }

    it 'retrieves values for each key' do
      sqlite_client.execute("INSERT INTO test_stats (key, data) VALUES ('metric::2023::01', json('{\"count\": 10, \"status\": \"active\"}'))")
      sqlite_client.execute("INSERT INTO test_stats (key, data) VALUES ('metric::2023::02', json('{\"count\": 5}'))")

      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10, 'status' => 'active'},
        {'count' => 5}
      ])
    end

    it 'unpacks nested values' do
      sqlite_client.execute("INSERT INTO test_stats (key, data) VALUES ('metric::2023::01', json('{\"stats.requests\": 100, \"stats.errors\": 5, \"simple\": 42}'))")

      result = driver.get(keys: [['metric', '2023', '01']])

      expect(result).to eq([{
        'stats' => {'requests' => 100, 'errors' => 5},
        'simple' => 42
      }])
    end

    it 'handles empty results' do
      result = driver.get(keys: [['metric', '2023', '01']])

      expect(result).to eq([{}])
    end

    it 'handles multiple keys with mixed data' do
      sqlite_client.execute("INSERT INTO test_stats (key, data) VALUES ('metric::2023::01', json('{\"count\": 10}'))")
      
      result = driver.get(keys: [['metric', '2023', '01'], ['metric', '2023', '02']])

      expect(result).to eq([
        {'count' => 10},
        {}
      ])
    end

    it 'handles invalid JSON gracefully' do
      sqlite_client.execute("INSERT INTO test_stats (key, data) VALUES ('metric::2023::01', 'invalid_json')")

      result = driver.get(keys: [['metric', '2023', '01']])

      expect(result).to eq([{}])
    end
  end
end