require 'mongo'

RSpec.describe Trifle::Stats::Driver::Mongo do
  let(:mongo_url) { ENV['MONGODB_URL'] || 'mongodb://mongo:27017/trifle_stats_test' }
  let(:mongo_client) { Mongo::Client.new(mongo_url) }
  let(:driver) { described_class.new(mongo_client, collection_name: 'test_stats_separated', joined_identifier: false) }

  before(:each) do
    # Ensure clean state - drop and recreate collection
    begin
      mongo_client['test_stats_separated'].drop
    rescue Mongo::Error::OperationFailure
      # Collection doesn't exist, which is fine
    end
    described_class.setup!(mongo_client, collection_name: 'test_stats_separated', joined_identifier: false)
  end

  after(:all) do
    client = Mongo::Client.new(ENV['MONGODB_URL'] || 'mongodb://mongo:27017/trifle_stats_test')
    client['test_stats_separated'].drop
    client.close
  end

  describe '#initialize' do
    it 'sets client, collection_name and separator' do
      driver = described_class.new(mongo_client, collection_name: 'custom_stats', joined_identifier: false)
      
      expect(driver.client).to eq(mongo_client)
      expect(driver.collection_name).to eq('custom_stats')
      expect(driver.separator).to be_nil
    end

    it 'uses default collection_name when not provided' do
      driver = described_class.new(mongo_client, joined_identifier: false)
      
      expect(driver.collection_name).to eq('trifle_stats')
    end
  end

  describe '.setup!' do
    let(:test_collection) { 'temp_test_collection_separated' }

    after do
      mongo_client[test_collection].drop
    end

    it 'creates collection with unique index on key, range, at' do
      described_class.setup!(mongo_client, collection_name: test_collection, joined_identifier: false)

      indexes = mongo_client[test_collection].indexes.to_a
      compound_index = indexes.find { |idx| idx['key'] == { 'key' => 1, 'range' => 1, 'at' => -1 } }

      expect(compound_index).not_to be_nil
      expect(compound_index['unique']).to be true
    end
  end

  describe '#inc' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 2)
      ]
    end
    let(:values) { { count: 5, duration: 100 } }

    it 'increments values for each key' do
      driver.inc(keys: keys, **values)

      result1 = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 1).first
      result2 = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 2).first

      expect(result1['data']).to eq({'count' => 5, 'duration' => 100})
      expect(result2['data']).to eq({'count' => 5, 'duration' => 100})
    end

    it 'increments existing values' do
      mongo_client['test_stats_separated'].insert_one(key: 'metric', range: 2023, at: 1, data: { count: 10 })
      
      driver.inc(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1)], count: 5)

      result = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 1).first
      expect(result['data']['count']).to eq(15)
    end

    it 'handles nested values using packer' do
      nested_values = { stats: { requests: 10, errors: 2 } }
      
      driver.inc(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1)], **nested_values)

      result = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 1).first
      expect(result['data']).to eq({
        'stats' => { 'requests' => 10, 'errors' => 2 }
      })
    end
  end

  describe '#set' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 2)
      ]
    end
    let(:values) { { count: 10, status: 'active' } }

    it 'sets values for each key' do
      driver.set(keys: keys, **values)

      result1 = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 1).first
      result2 = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 2).first

      expect(result1['data']).to eq({'count' => 10, 'status' => 'active'})
      expect(result2['data']).to eq({'count' => 10, 'status' => 'active'})
    end

    it 'overwrites existing values' do
      mongo_client['test_stats_separated'].insert_one(key: 'metric', range: 2023, at: 1, data: { count: 100 })
      
      driver.set(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1)], count: 10)

      result = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 1).first
      expect(result['data']['count']).to eq(10)
    end

    it 'handles nested values using packer' do
      nested_values = { config: { enabled: true, limit: 50 } }
      
      driver.set(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1)], **nested_values)

      result = mongo_client['test_stats_separated'].find(key: 'metric', range: 2023, at: 1).first
      expect(result['data']).to eq({
        'config' => { 'enabled' => true, 'limit' => 50 }
      })
    end
  end

  describe '#get' do
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 2)
      ]
    end

    it 'retrieves values for each key' do
      mongo_client['test_stats_separated'].insert_one(key: 'metric', range: 2023, at: 1, data: { count: 10, status: 'active' })
      mongo_client['test_stats_separated'].insert_one(key: 'metric', range: 2023, at: 2, data: { count: 5 })

      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10, 'status' => 'active'},
        {'count' => 5}
      ])
    end

    it 'handles empty results' do
      result = driver.get(keys: [Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1)])

      expect(result).to eq([{}])
    end

    it 'handles multiple keys with mixed data' do
      mongo_client['test_stats_separated'].insert_one(key: 'metric', range: 2023, at: 1, data: { count: 10 })
      
      result = driver.get(keys: [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 2)
      ])

      expect(result).to eq([
        {'count' => 10},
        {}
      ])
    end
  end

  describe '#scan' do
    let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1) }

    it 'returns latest data for key' do
      # Insert multiple records with different timestamps
      mongo_client['test_stats_separated'].insert_one(key: 'metric', range: 2023, at: 1, data: { count: 10 })
      mongo_client['test_stats_separated'].insert_one(key: 'metric', range: 2023, at: 2, data: { count: 20 })
      
      result = driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'metric'))

      expect(result).to eq([2, { 'count' => 20 }])
    end

    it 'returns empty array when no data found' do
      result = driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'nonexistent'))

      expect(result).to eq([])
    end
  end

  describe '#ping' do
    let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', range: 2023, at: 1) }
    let(:values) { { status: 'active', count: 1 } }

    it 'stores ping data' do
      driver.ping(key: key, **values)

      result = mongo_client['test_stats_separated'].find(key: 'metric').first
      expect(result['data']['status']).to eq('active')
      expect(result['data']['count']).to eq(1)
      expect(result['at']).to eq(1)
    end
  end
end