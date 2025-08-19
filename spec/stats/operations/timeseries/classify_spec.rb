require 'time'

RSpec.describe Trifle::Stats::Operations::Timeseries::Classify do
  let(:mock_driver) { instance_double(Trifle::Stats::Driver::Process) }
  let(:mock_tz) { instance_double(TZInfo::Timezone, utc_offset: 0) }
  let(:mock_designator) { instance_double(Trifle::Stats::Designator::Linear) }
  let(:mock_config) do
    instance_double(Trifle::Stats::Configuration).tap do |config|
      allow(config).to receive(:driver).and_return(mock_driver)
      allow(config).to receive(:granularities).and_return([:hour, :day])
      allow(config).to receive(:time_zone).and_return('UTC')
      allow(config).to receive(:beginning_of_week).and_return(:monday)
      allow(config).to receive(:tz).and_return(mock_tz)
      allow(config).to receive(:designator).and_return(mock_designator)
    end
  end
  let(:at_time) { Time.parse('2023-01-15 14:30:00 UTC') }
  let(:key) { 'test::metric' }
  let(:values) { { response_time: 150, request_size: 1024 } }

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

  describe '#classify' do
    let(:operation) { described_class.new(key: key, at: at_time, values: values, config: mock_config) }

    it 'calls designator.designate and converts to string' do
      allow(mock_designator).to receive(:designate).with(value: 150).and_return('medium')

      result = operation.classify(150)

      expect(result).to eq('medium')
    end

    it 'replaces dots with underscores in designation' do
      allow(mock_designator).to receive(:designate).with(value: 1.5).and_return('1.5_granularity')

      result = operation.classify(1.5)

      expect(result).to eq('1_5_granularity')
    end

    it 'handles numeric designations' do
      allow(mock_designator).to receive(:designate).with(value: 100).and_return(42)

      result = operation.classify(100)

      expect(result).to eq('42')
    end
  end

  describe '#deep_classify' do
    let(:operation) { described_class.new(key: key, at: at_time, values: values, config: mock_config) }

    it 'classifies simple hash values' do
      allow(mock_designator).to receive(:designate).with(value: 150).and_return('medium')
      allow(mock_designator).to receive(:designate).with(value: 1024).and_return('large')

      result = operation.deep_classify({ response_time: 150, request_size: 1024 })

      expect(result).to eq({
        response_time: { 'medium' => 1 },
        request_size: { 'large' => 1 }
      })
    end

    it 'handles nested hash structures' do
      allow(mock_designator).to receive(:designate).with(value: 200).and_return('high')
      allow(mock_designator).to receive(:designate).with(value: 50).and_return('low')
      allow(mock_designator).to receive(:designate).with(value: 512).and_return('medium')

      nested_values = {
        performance: {
          cpu: 200,
          memory: 50
        },
        size: 512
      }

      result = operation.deep_classify(nested_values)

      expect(result).to eq({
        performance: {
          cpu: { 'high' => 1 },
          memory: { 'low' => 1 }
        },
        size: { 'medium' => 1 }
      })
    end

    it 'handles deeply nested structures' do
      allow(mock_designator).to receive(:designate).with(value: 100).and_return('bucket_1')
      allow(mock_designator).to receive(:designate).with(value: 300).and_return('bucket_3')

      deep_values = {
        level1: {
          level2: {
            level3: {
              metric1: 100,
              metric2: 300
            }
          }
        }
      }

      result = operation.deep_classify(deep_values)

      expect(result).to eq({
        level1: {
          level2: {
            level3: {
              metric1: { 'bucket_1' => 1 },
              metric2: { 'bucket_3' => 1 }
            }
          }
        }
      })
    end
  end

  describe '#key_for' do
    let(:operation) { described_class.new(key: key, at: at_time, values: values, config: mock_config) }

    it 'returns formatted key for given granularity' do
      result = operation.key_for(granularity: :hour)

      expect(result).to be_a(Trifle::Stats::Nocturnal::Key)
      expect(result.key).to eq(key)
      expect(result.granularity).to eq(:hour)
      expect(result.at).to eq(Time.parse('2023-01-15 14:00:00 UTC'))
    end

    it 'returns formatted key for day granularity' do
      result = operation.key_for(granularity: :day)

      expect(result).to be_a(Trifle::Stats::Nocturnal::Key)
      expect(result.key).to eq(key)
      expect(result.granularity).to eq(:day)
      expect(result.at).to eq(Time.parse('2023-01-15 00:00:00 UTC'))
    end
  end

  describe '#perform' do
    let(:operation) { described_class.new(key: key, at: at_time, values: values, config: mock_config) }

    it 'calls driver.inc with classified values' do
      allow(mock_designator).to receive(:designate).with(value: 150).and_return('medium')
      allow(mock_designator).to receive(:designate).with(value: 1024).and_return('large')

      expect(mock_driver).to receive(:inc) do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(2)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[0].key).to eq(key)
        expect(keys[0].granularity).to eq(:hour)
        expect(keys[0].at).to eq(Time.parse('2023-01-15 14:00:00 UTC'))
        
        expect(keys[1]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[1].key).to eq(key)
        expect(keys[1].granularity).to eq(:day)
        expect(keys[1].at).to eq(Time.parse('2023-01-15 00:00:00 UTC'))
        
        expect(args[:response_time]).to eq({ 'medium' => 1 })
        expect(args[:request_size]).to eq({ 'large' => 1 })
      end

      operation.perform
    end

    it 'handles nested values correctly' do
      allow(mock_designator).to receive(:designate).with(value: 200).and_return('high')
      allow(mock_designator).to receive(:designate).with(value: 50).and_return('low')

      nested_values = {
        performance: {
          cpu: 200,
          memory: 50
        }
      }

      operation = described_class.new(key: key, at: at_time, values: nested_values, config: mock_config)

      expect(mock_driver).to receive(:inc) do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(2)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[1]).to be_a(Trifle::Stats::Nocturnal::Key)
        
        expected_values = {
          performance: {
            cpu: { 'high' => 1 },
            memory: { 'low' => 1 }
          }
        }
        
        expect(args[:performance]).to eq(expected_values[:performance])
      end

      operation.perform
    end

    it 'works with single granularity configuration' do
      allow(mock_config).to receive(:granularities).and_return([:day])
      allow(mock_designator).to receive(:designate).with(value: 150).and_return('medium')
      allow(mock_designator).to receive(:designate).with(value: 1024).and_return('large')

      operation = described_class.new(key: key, at: at_time, values: values, config: mock_config)

      expect(mock_driver).to receive(:inc) do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(1)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[0].key).to eq(key)
        expect(keys[0].granularity).to eq(:day)
        expect(keys[0].at).to eq(Time.parse('2023-01-15 00:00:00 UTC'))
        
        expect(args[:response_time]).to eq({ 'medium' => 1 })
        expect(args[:request_size]).to eq({ 'large' => 1 })
      end

      operation.perform
    end
  end
end