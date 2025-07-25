require 'time'

RSpec.describe Trifle::Stats::Operations::Timeseries::Values do
  let(:mock_driver) { instance_double(Trifle::Stats::Driver::Process) }
  let(:mock_config) do
    instance_double(Trifle::Stats::Configuration).tap do |config|
      allow(config).to receive(:driver).and_return(mock_driver)
    end
  end
  let(:from_time) { Time.parse('2023-01-15 10:00:00 UTC') }
  let(:to_time) { Time.parse('2023-01-15 12:00:00 UTC') }
  let(:key) { 'test::metric' }
  let(:range) { :hour }

  describe '#initialize' do
    it 'sets required attributes' do
      operation = described_class.new(key: key, from: from_time, to: to_time, range: range)

      expect(operation.key).to eq(key)
      expect(operation.range).to eq(range)
    end

    it 'accepts optional config' do
      operation = described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config)

      expect(operation.config).to eq(mock_config)
    end

    it 'accepts optional skip_blanks parameter' do
      operation = described_class.new(key: key, from: from_time, to: to_time, range: range, skip_blanks: true)

      expect(operation.instance_variable_get(:@skip_blanks)).to be true
    end

    it 'raises error when required parameters are missing' do
      expect { described_class.new(from: from_time, to: to_time, range: range) }.to raise_error(KeyError)
      expect { described_class.new(key: key, to: to_time, range: range) }.to raise_error(KeyError)
      expect { described_class.new(key: key, from: from_time, range: range) }.to raise_error(KeyError)
      expect { described_class.new(key: key, from: from_time, to: to_time) }.to raise_error(KeyError)
    end
  end

  describe '#config' do
    it 'returns provided config when given' do
      operation = described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config)

      expect(operation.config).to eq(mock_config)
    end

    it 'returns default config when not provided' do
      allow(Trifle::Stats).to receive(:default).and_return(mock_config)
      operation = described_class.new(key: key, from: from_time, to: to_time, range: range)

      expect(operation.config).to eq(mock_config)
    end
  end

  describe '#timeline' do
    let(:operation) { described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config) }

    it 'generates timeline using Nocturnal.timeline' do
      expected_timeline = [
        Time.parse('2023-01-15 10:00:00 UTC'),
        Time.parse('2023-01-15 11:00:00 UTC'),
        Time.parse('2023-01-15 12:00:00 UTC')
      ]

      expect(Trifle::Stats::Nocturnal).to receive(:timeline).with(
        from: from_time,
        to: to_time,
        range: range
      ).and_return(expected_timeline)

      result = operation.timeline

      expect(result).to eq(expected_timeline)
    end

    it 'memoizes timeline result' do
      expected_timeline = [Time.parse('2023-01-15 10:00:00 UTC')]
      
      expect(Trifle::Stats::Nocturnal).to receive(:timeline).once.and_return(expected_timeline)

      operation.timeline
      operation.timeline # Second call should use memoized result
    end
  end

  describe '#data' do
    let(:operation) { described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config) }
    let(:timeline) { [Time.parse('2023-01-15 10:00:00 UTC'), Time.parse('2023-01-15 11:00:00 UTC')] }

    before do
      allow(operation).to receive(:timeline).and_return(timeline)
    end

    it 'calls driver.get with correct keys' do
      expected_data = [{ 'count' => 10 }, { 'count' => 15 }]

      expect(mock_driver).to receive(:get) do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(2)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[0].key).to eq(key)
        expect(keys[0].range).to eq(range)
        expect(keys[0].at).to eq(Time.parse('2023-01-15 10:00:00 UTC'))
        
        expect(keys[1]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[1].key).to eq(key)
        expect(keys[1].range).to eq(range)
        expect(keys[1].at).to eq(Time.parse('2023-01-15 11:00:00 UTC'))
        
        expected_data
      end

      result = operation.data

      expect(result).to eq(expected_data)
    end

    it 'memoizes data result' do
      expected_data = [{ 'count' => 10 }, { 'count' => 15 }]

      expect(mock_driver).to receive(:get).once do |args|
        keys = args[:keys]
        expect(keys).to be_an(Array)
        expect(keys.length).to eq(2)
        
        expect(keys[0]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[0].key).to eq(key)
        expect(keys[0].range).to eq(range)
        expect(keys[0].at).to eq(Time.parse('2023-01-15 10:00:00 UTC'))
        
        expect(keys[1]).to be_a(Trifle::Stats::Nocturnal::Key)
        expect(keys[1].key).to eq(key)
        expect(keys[1].range).to eq(range)
        expect(keys[1].at).to eq(Time.parse('2023-01-15 11:00:00 UTC'))
        
        expected_data
      end

      operation.data
      operation.data # Second call should use memoized result
    end
  end

  describe '#values' do
    let(:operation) { described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config) }
    let(:timeline) { [Time.parse('2023-01-15 10:00:00 UTC'), Time.parse('2023-01-15 11:00:00 UTC')] }
    let(:data) { [{ 'count' => 10 }, { 'count' => 15 }] }

    before do
      allow(operation).to receive(:timeline).and_return(timeline)
      allow(operation).to receive(:data).and_return(data)
    end

    it 'returns timeline and data structure' do
      result = operation.values

      expect(result).to eq({
        at: timeline,
        values: data
      })
    end
  end

  describe '#clean_values' do
    let(:operation) { described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config) }
    let(:timeline) do
      [
        Time.parse('2023-01-15 10:00:00 UTC'),
        Time.parse('2023-01-15 11:00:00 UTC'),
        Time.parse('2023-01-15 12:00:00 UTC')
      ]
    end
    let(:data) { [{ 'count' => 10 }, {}, { 'count' => 15 }] }

    before do
      allow(operation).to receive(:timeline).and_return(timeline)
      allow(operation).to receive(:data).and_return(data)
    end

    it 'filters out empty data points' do
      result = operation.clean_values

      expect(result).to eq({
        at: [
          Time.parse('2023-01-15 10:00:00 UTC'),
          Time.parse('2023-01-15 12:00:00 UTC')
        ],
        values: [
          { 'count' => 10 },
          { 'count' => 15 }
        ]
      })
    end

    it 'handles all empty data' do
      allow(operation).to receive(:data).and_return([{}, {}, {}])

      result = operation.clean_values

      expect(result).to eq({
        at: [],
        values: []
      })
    end

    it 'handles all non-empty data' do
      allow(operation).to receive(:data).and_return([{ 'count' => 10 }, { 'count' => 20 }, { 'count' => 30 }])

      result = operation.clean_values

      expect(result).to eq({
        at: timeline,
        values: [{ 'count' => 10 }, { 'count' => 20 }, { 'count' => 30 }]
      })
    end
  end

  describe '#perform' do
    let(:timeline) { [Time.parse('2023-01-15 10:00:00 UTC'), Time.parse('2023-01-15 11:00:00 UTC')] }
    let(:data) { [{ 'count' => 10 }, { 'count' => 15 }] }

    context 'when skip_blanks is false' do
      let(:operation) { described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config, skip_blanks: false) }

      before do
        allow(operation).to receive(:timeline).and_return(timeline)
        allow(operation).to receive(:data).and_return(data)
      end

      it 'returns full values' do
        result = operation.perform

        expect(result).to eq({
          at: timeline,
          values: data
        })
      end
    end

    context 'when skip_blanks is true' do
      let(:operation) { described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config, skip_blanks: true) }
      let(:timeline_with_blanks) { [Time.parse('2023-01-15 10:00:00 UTC'), Time.parse('2023-01-15 11:00:00 UTC'), Time.parse('2023-01-15 12:00:00 UTC')] }
      let(:data_with_blanks) { [{ 'count' => 10 }, {}, { 'count' => 15 }] }

      before do
        allow(operation).to receive(:timeline).and_return(timeline_with_blanks)
        allow(operation).to receive(:data).and_return(data_with_blanks)
      end

      it 'returns cleaned values' do
        result = operation.perform

        expect(result).to eq({
          at: [
            Time.parse('2023-01-15 10:00:00 UTC'),
            Time.parse('2023-01-15 12:00:00 UTC')
          ],
          values: [
            { 'count' => 10 },
            { 'count' => 15 }
          ]
        })
      end
    end

    context 'when skip_blanks is nil (default)' do
      let(:operation) { described_class.new(key: key, from: from_time, to: to_time, range: range, config: mock_config) }

      before do
        allow(operation).to receive(:timeline).and_return(timeline)
        allow(operation).to receive(:data).and_return(data)
      end

      it 'returns full values (default behavior)' do
        result = operation.perform

        expect(result).to eq({
          at: timeline,
          values: data
        })
      end
    end
  end
end