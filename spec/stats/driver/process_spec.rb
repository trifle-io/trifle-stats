RSpec.describe Trifle::Stats::Driver::Process do
  let(:driver) { described_class.new }

  before(:each) do
    driver.instance_variable_set(:@data, {})
  end

  describe '#initialize' do
    it 'initializes with empty data hash and separator' do
      driver = described_class.new
      
      expect(driver.instance_variable_get(:@data)).to eq({})
      expect(driver.instance_variable_get(:@separator)).to eq('::')
    end
  end

  describe '#inc' do
    let(:keys) { [['metric', '2023', '01'], ['metric', '2023', '02']] }
    let(:values) { { count: 5, duration: 100 } }

    it 'increments values for each key' do
      driver.inc(keys: keys, values: values)

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']).to eq({'count' => 5, 'duration' => 100})
      expect(data['metric::2023::02']).to eq({'count' => 5, 'duration' => 100})
    end

    it 'increments existing values' do
      driver.instance_variable_get(:@data)['metric::2023::01'] = {'count' => 10}
      
      driver.inc(keys: [['metric', '2023', '01']], values: { count: 5 })

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']['count']).to eq(15)
    end

    it 'handles nested values using packer' do
      nested_values = { stats: { requests: 10, errors: 2 } }
      
      driver.inc(keys: [['metric', '2023', '01']], values: nested_values)

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']).to eq({
        'stats.requests' => 10,
        'stats.errors' => 2
      })
    end

    it 'handles zero values correctly' do
      driver.inc(keys: [['metric', '2023', '01']], values: { count: 0 })

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']).to eq({'count' => 0})
    end
  end

  describe '#set' do
    let(:keys) { [['metric', '2023', '01'], ['metric', '2023', '02']] }
    let(:values) { { count: 10, status: 'active' } }

    it 'sets values for each key' do
      driver.set(keys: keys, values: values)

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']).to eq({'count' => 10, 'status' => 'active'})
      expect(data['metric::2023::02']).to eq({'count' => 10, 'status' => 'active'})
    end

    it 'overwrites existing values' do
      driver.instance_variable_get(:@data)['metric::2023::01'] = {'count' => 100}
      
      driver.set(keys: [['metric', '2023', '01']], values: { count: 10 })

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']['count']).to eq(10)
    end

    it 'handles nested values using packer' do
      nested_values = { config: { enabled: true, limit: 50 } }
      
      driver.set(keys: [['metric', '2023', '01']], values: nested_values)

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']).to eq({
        'config.enabled' => true,
        'config.limit' => 50
      })
    end

    it 'preserves non-overwritten keys' do
      driver.instance_variable_get(:@data)['metric::2023::01'] = {'count' => 100, 'other' => 'value'}
      
      driver.set(keys: [['metric', '2023', '01']], values: { count: 10 })

      data = driver.instance_variable_get(:@data)
      expect(data['metric::2023::01']).to eq({'count' => 10, 'other' => 'value'})
    end
  end

  describe '#get' do
    let(:keys) { [['metric', '2023', '01'], ['metric', '2023', '02']] }

    it 'retrieves values for each key' do
      data = driver.instance_variable_get(:@data)
      data['metric::2023::01'] = {'count' => 10, 'status' => 'active'}
      data['metric::2023::02'] = {'count' => 5}

      result = driver.get(keys: keys)

      expect(result).to eq([
        {'count' => 10, 'status' => 'active'},
        {'count' => 5}
      ])
    end

    it 'unpacks nested values' do
      data = driver.instance_variable_get(:@data)
      data['metric::2023::01'] = {
        'stats.requests' => 100,
        'stats.errors' => 5,
        'simple' => 42
      }

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
      data = driver.instance_variable_get(:@data)
      data['metric::2023::01'] = {'count' => 10}
      
      result = driver.get(keys: [['metric', '2023', '01'], ['metric', '2023', '02']])

      expect(result).to eq([
        {'count' => 10},
        {}
      ])
    end

    it 'handles keys with special characters' do
      special_keys = [['metric with spaces', '2023-01', 'user@example.com']]
      driver.set(keys: special_keys, values: { count: 42 })

      result = driver.get(keys: special_keys)

      expect(result).to eq([{'count' => 42}])
    end
  end
end