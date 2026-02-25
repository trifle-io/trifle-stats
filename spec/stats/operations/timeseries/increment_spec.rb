require 'time'

RSpec.describe Trifle::Stats::Operations::Timeseries::Increment do
  let(:mock_driver) { instance_double(Trifle::Stats::Driver::Process) }
  let(:mock_tz) do
    instance_double(TZInfo::Timezone, utc_offset: 0).tap do |tz|
      allow(tz).to receive(:utc_to_local) { |time| time }
    end
  end
  let(:mock_config) do
    instance_double(Trifle::Stats::Configuration).tap do |config|
      allow(config).to receive(:driver).and_return(mock_driver)
      allow(config).to receive(:storage).and_return(mock_driver)
      allow(config).to receive(:granularities).and_return(['1h', '1d'])
      allow(config).to receive(:time_zone).and_return('UTC')
      allow(config).to receive(:beginning_of_week).and_return(:monday)
      allow(config).to receive(:tz).and_return(mock_tz)
    end
  end
  let(:at_time) { Time.parse('2023-01-15 14:30:00 UTC') }
  let(:key) { 'test::metric' }
  let(:values) { { count: 5, duration: 100 } }

  describe '#initialize' do
    it 'sets required attributes' do
      operation = described_class.new(key: key, at: at_time, values: values)

      expect(operation.key).to eq(key)
      expect(operation.values).to eq(values)
    end

    it 'accepts optional config' do
      operation = described_class.new(key: key, at: at_time, values: values, config: mock_config)

      expect(operation.config).to eq(mock_config)
    end

    it 'raises error when required parameters are missing' do
      expect { described_class.new(at: at_time, values: values) }.to raise_error(KeyError)
      expect { described_class.new(key: key, values: values) }.to raise_error(KeyError)
      expect { described_class.new(key: key, at: at_time) }.to raise_error(KeyError)
    end
  end

  describe '#config' do
    it 'returns provided config when given' do
      operation = described_class.new(key: key, at: at_time, values: values, config: mock_config)

      expect(operation.config).to eq(mock_config)
    end

    it 'returns default config when not provided' do
      allow(Trifle::Stats).to receive(:default).and_return(mock_config)
      operation = described_class.new(key: key, at: at_time, values: values)

      expect(operation.config).to eq(mock_config)
    end
  end

  describe '#key_for' do
    let(:operation) { described_class.new(key: key, at: at_time, values: values, config: mock_config) }

    it 'returns formatted key for given granularity' do
      result = operation.key_for(granularity: '1h')

      expect(result).to be_a(Trifle::Stats::Nocturnal::Key)
      expect(result.key).to eq(key)
      expect(result.granularity).to eq('1h')
      expect(result.at).to eq(Time.parse('2023-01-15 14:00:00 UTC'))
    end

    it 'returns formatted key for day granularity' do
      result = operation.key_for(granularity: '1d')

      expect(result).to be_a(Trifle::Stats::Nocturnal::Key)
      expect(result.key).to eq(key)
      expect(result.granularity).to eq('1d')
      expect(result.at).to eq(Time.parse('2023-01-15 00:00:00 UTC'))
    end
  end

  describe '#perform' do
    let(:operation) { described_class.new(key: key, at: at_time, values: values, config: mock_config) }

    it 'calls driver.inc with correct parameters' do
      expect(mock_driver).to receive(:inc) do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(2)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[0].key).to eq(key)
        expect(keys[0].granularity).to eq('1h')
        expect(keys[0].at).to eq(Time.parse('2023-01-15 14:00:00 UTC'))
        
        expect(keys[1]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[1].key).to eq(key)
        expect(keys[1].granularity).to eq('1d')
        expect(keys[1].at).to eq(Time.parse('2023-01-15 00:00:00 UTC'))
        
        expect(args[:values]).to eq({ count: 5, duration: 100 })
      end

      operation.perform
    end

    it 'passes through all values to driver' do
      complex_values = { count: 10, duration: 200, nested: { requests: 5, errors: 1 } }
      operation = described_class.new(key: key, at: at_time, values: complex_values, config: mock_config)

      expect(mock_driver).to receive(:inc).with(
        keys: anything,
        values: {
          count: 10,
          duration: 200,
          nested: { requests: 5, errors: 1 }
        }
      )

      operation.perform
    end

    it 'works with single granularity configuration' do
      allow(mock_config).to receive(:granularities).and_return(['1d'])
      operation = described_class.new(key: key, at: at_time, values: values, config: mock_config)

      expect(mock_driver).to receive(:inc) do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(1)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[0].key).to eq(key)
        expect(keys[0].granularity).to eq('1d')
        expect(keys[0].at).to eq(Time.parse('2023-01-15 00:00:00 UTC'))
        
        expect(args[:values]).to eq({ count: 5, duration: 100 })
      end

      operation.perform
    end

    it 'works with multiple granularities' do
      allow(mock_config).to receive(:granularities).and_return(['1m', '1h', '1d', '1mo'])
      operation = described_class.new(key: key, at: at_time, values: values, config: mock_config)

      expect(mock_driver).to receive(:inc) do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(4)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[0].key).to eq(key)
        expect(keys[0].granularity).to eq('1m')
        expect(keys[0].at).to eq(Time.parse('2023-01-15 14:30:00 UTC'))
        
        expect(keys[1]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[1].key).to eq(key)
        expect(keys[1].granularity).to eq('1h')
        expect(keys[1].at).to eq(Time.parse('2023-01-15 14:00:00 UTC'))
        
        expect(keys[2]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[2].key).to eq(key)
        expect(keys[2].granularity).to eq('1d')
        expect(keys[2].at).to eq(Time.parse('2023-01-15 00:00:00 UTC'))
        
        expect(keys[3]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[3].key).to eq(key)
        expect(keys[3].granularity).to eq('1mo')
        expect(keys[3].at).to eq(Time.parse('2023-01-01 00:00:00 UTC'))
        
        expect(args[:values]).to eq({ count: 5, duration: 100 })
      end

      operation.perform
    end
  end
end
