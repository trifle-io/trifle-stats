require 'time'

RSpec.describe Trifle::Stats::Series do
  let(:series_data) do
    {
      at: [Time.parse('2023-01-01 10:00:00'), Time.parse('2023-01-01 11:00:00')],
      values: [{ 'count' => 10, 'errors' => 2 }, { 'count' => 15, 'errors' => 3 }]
    }
  end

  describe '#initialize' do
    it 'sets series data and normalizes values' do
      series = described_class.new(series_data)

      expect(series.series).to eq({
        at: [Time.parse('2023-01-01 10:00:00'), Time.parse('2023-01-01 11:00:00')],
        values: [{ 'count' => 10, 'errors' => 2 }, { 'count' => 15, 'errors' => 3 }]
      })
    end

    it 'normalizes symbol keys to string keys in values' do
      symbol_data = {
        at: [Time.parse('2023-01-01 10:00:00')],
        values: [{ count: 10, errors: 2 }]
      }

      series = described_class.new(symbol_data)

      expect(series.series[:values]).to eq([{ 'count' => 10, 'errors' => 2 }])
    end

    it 'handles empty values array' do
      empty_data = { at: [], values: [] }

      series = described_class.new(empty_data)

      expect(series.series).to eq({ at: [], values: [] })
    end

    it 'includes Packer mixin' do
      expect(described_class.ancestors).to include(Trifle::Stats::Mixins::Packer)
    end
  end

  describe '#series' do
    let(:series) { described_class.new(series_data) }

    it 'provides access to series data' do
      expect(series.series).to be_a(Hash)
      expect(series.series.keys).to contain_exactly(:at, :values)
    end

    it 'allows modification of series data' do
      series.series[:custom_field] = 'test'

      expect(series.series[:custom_field]).to eq('test')
    end
  end

  describe 'Aggregator' do
    let(:series) { described_class.new(series_data) }

    describe '#aggregate' do
      it 'returns Aggregator instance' do
        result = series.aggregate

        expect(result).to be_a(described_class::Aggregator)
      end

      it 'memoizes the aggregator instance' do
        aggregator1 = series.aggregate
        aggregator2 = series.aggregate

        expect(aggregator1).to be(aggregator2)
      end

      it 'passes series to aggregator' do
        aggregator = series.aggregate

        expect(aggregator.instance_variable_get(:@series)).to eq(series)
      end
    end

    describe '.register_aggregator' do
      let(:mock_aggregator_class) do
        Class.new do
          def aggregate(series:, **params)
            "aggregated with #{params[:type]}"
          end
        end
      end

      before do
        described_class.register_aggregator(:test_sum, mock_aggregator_class)
      end

      it 'registers aggregator method on Aggregator class' do
        expect(described_class::Aggregator.instance_methods).to include(:test_sum)
      end

      it 'calls registered aggregator with correct parameters' do
        result = series.aggregate.test_sum(type: 'sum')

        expect(result).to eq('aggregated with sum')
      end

      it 'passes series data to aggregator' do
        mock_instance = mock_aggregator_class.new
        allow(mock_aggregator_class).to receive(:new).and_return(mock_instance)

        expect(mock_instance).to receive(:aggregate).with(
          series: series.series,
          type: 'custom'
        )

        series.aggregate.test_sum(type: 'custom')
      end
    end
  end

  describe 'Formatter' do
    let(:series) { described_class.new(series_data) }

    describe '#format' do
      it 'returns Formatter instance' do
        result = series.format

        expect(result).to be_a(described_class::Formatter)
      end

      it 'memoizes the formatter instance' do
        formatter1 = series.format
        formatter2 = series.format

        expect(formatter1).to be(formatter2)
      end

      it 'passes series to formatter' do
        formatter = series.format

        expect(formatter.instance_variable_get(:@series)).to eq(series)
      end
    end

    describe '.register_formatter' do
      let(:mock_formatter_class) do
        Class.new do
          def format(series:, **params, &block)
            result = "formatted with #{params[:style]}"
            result += " and block" if block_given?
            result
          end
        end
      end

      before do
        described_class.register_formatter(:test_table, mock_formatter_class)
      end

      it 'registers formatter method on Formatter class' do
        expect(described_class::Formatter.instance_methods).to include(:test_table)
      end

      it 'calls registered formatter with correct parameters' do
        result = series.format.test_table(style: 'table')

        expect(result).to eq('formatted with table')
      end

      it 'passes block to formatter' do
        result = series.format.test_table(style: 'table') { 'block content' }

        expect(result).to eq('formatted with table and block')
      end

      it 'passes series data to formatter' do
        mock_instance = mock_formatter_class.new
        allow(mock_formatter_class).to receive(:new).and_return(mock_instance)

        expect(mock_instance).to receive(:format).with(
          series: series.series,
          style: 'custom'
        )

        series.format.test_table(style: 'custom')
      end
    end
  end

  describe 'Transponder' do
    let(:series) { described_class.new(series_data) }

    describe '#transpond' do
      it 'returns Transponder instance' do
        result = series.transpond

        expect(result).to be_a(described_class::Transponder)
      end

      it 'memoizes the transponder instance' do
        transponder1 = series.transpond
        transponder2 = series.transpond

        expect(transponder1).to be(transponder2)
      end

      it 'passes series to transponder' do
        transponder = series.transpond

        expect(transponder.instance_variable_get(:@series)).to eq(series)
      end
    end

    describe '.register_transponder' do
      let(:mock_transponder_class) do
        Class.new do
          def transpond(series:, **params)
            modified_series = series.dup
            modified_series[:transformed] = params[:operation]
            modified_series
          end
        end
      end

      before do
        described_class.register_transponder(:test_transform, mock_transponder_class)
      end

      it 'registers transponder method on Transponder class' do
        expect(described_class::Transponder.instance_methods).to include(:test_transform)
      end

      it 'calls registered transponder and modifies series data' do
        original_series = series.series.dup

        series.transpond.test_transform(operation: 'normalize')

        expect(series.series[:transformed]).to eq('normalize')
        expect(series.series[:at]).to eq(original_series[:at])
        expect(series.series[:values]).to eq(original_series[:values])
      end

      it 'passes series data to transponder' do
        mock_instance = mock_transponder_class.new
        allow(mock_transponder_class).to receive(:new).and_return(mock_instance)

        expect(mock_instance).to receive(:transpond).with(
          series: series.series,
          operation: 'scale'
        ).and_return(series.series)

        series.transpond.test_transform(operation: 'scale')
      end
    end
  end

  describe 'nested class instantiation' do
    let(:series) { described_class.new(series_data) }

    describe 'Aggregator' do
      it 'can be instantiated with series' do
        aggregator = described_class::Aggregator.new(series)

        expect(aggregator).to be_a(described_class::Aggregator)
        expect(aggregator.instance_variable_get(:@series)).to eq(series)
      end
    end

    describe 'Formatter' do
      it 'can be instantiated with series' do
        formatter = described_class::Formatter.new(series)

        expect(formatter).to be_a(described_class::Formatter)
        expect(formatter.instance_variable_get(:@series)).to eq(series)
      end
    end

    describe 'Transponder' do
      it 'can be instantiated with series' do
        transponder = described_class::Transponder.new(series)

        expect(transponder).to be_a(described_class::Transponder)
        expect(transponder.instance_variable_get(:@series)).to eq(series)
      end
    end
  end

  describe 'complex integration scenarios' do
    let(:complex_data) do
      {
        at: [
          Time.parse('2023-01-01 10:00:00'),
          Time.parse('2023-01-01 11:00:00'),
          Time.parse('2023-01-01 12:00:00')
        ],
        values: [
          { 'requests' => 100, 'errors' => 5, 'avg_time' => 250 },
          { 'requests' => 150, 'errors' => 8, 'avg_time' => 300 },
          { 'requests' => 120, 'errors' => 3, 'avg_time' => 200 }
        ]
      }
    end
    let(:series) { described_class.new(complex_data) }

    it 'handles complex data structures' do
      expect(series.series[:at].length).to eq(3)
      expect(series.series[:values].length).to eq(3)
      expect(series.series[:values].first.keys).to contain_exactly('requests', 'errors', 'avg_time')
    end

    it 'allows chaining of different operations' do
      # Register mock implementations
      described_class.register_aggregator(:sum_requests, Class.new do
        def aggregate(series:, **params)
          series[:values].sum { |v| v['requests'] || 0 }
        end
      end)

      described_class.register_formatter(:to_csv, Class.new do
        def format(series:, **params)
          "CSV formatted data"
        end
      end)

      # Chain operations
      total_requests = series.aggregate.sum_requests({})
      csv_output = series.format.to_csv({})

      expect(total_requests).to eq(370) # 100 + 150 + 120
      expect(csv_output).to eq("CSV formatted data")
    end
  end
end