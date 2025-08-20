require 'time'

RSpec.describe Trifle::Stats::Nocturnal do
  let(:mock_tz) { instance_double(TZInfo::Timezone, utc_offset: 0) }
  let(:mock_config) do
    instance_double(Trifle::Stats::Configuration).tap do |config|
      allow(config).to receive(:tz).and_return(mock_tz)
      allow(config).to receive(:beginning_of_week).and_return(:monday)
    end
  end
  let(:test_time) { Time.parse('2023-03-15 14:30:45 UTC') } # Wednesday

  describe 'DAYS_INTO_WEEK constant' do
    it 'defines correct day mappings' do
      expect(described_class::DAYS_INTO_WEEK).to eq({
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      })
    end
  end

  describe '.timeline' do
    let(:from_time) { Time.parse('2023-03-15 10:00:00 UTC') }
    let(:to_time) { Time.parse('2023-03-15 12:00:00 UTC') }

    it 'generates timeline for hour granularity' do
      result = described_class.timeline(from: from_time, to: to_time, offset: 1, unit: :hour, config: mock_config)

      expect(result).to eq([
        Time.parse('2023-03-15 10:00:00 UTC'),
        Time.parse('2023-03-15 11:00:00 UTC'),
        Time.parse('2023-03-15 12:00:00 UTC')
      ])
    end

    it 'generates timeline for day granularity' do
      from_day = Time.parse('2023-03-15 00:00:00 UTC')
      to_day = Time.parse('2023-03-17 00:00:00 UTC')

      result = described_class.timeline(from: from_day, to: to_day, offset: 1, unit: :day, config: mock_config)

      expect(result).to eq([
        Time.parse('2023-03-15 00:00:00 UTC'),
        Time.parse('2023-03-16 00:00:00 UTC'),
        Time.parse('2023-03-17 00:00:00 UTC')
      ])
    end

    it 'handles single point timeline' do
      result = described_class.timeline(from: from_time, to: from_time, offset: 1, unit: :hour, config: mock_config)

      expect(result).to eq([Time.parse('2023-03-15 10:00:00 UTC')])
    end

    it 'uses default config when not provided' do
      allow(Trifle::Stats).to receive(:default).and_return(mock_config)

      result = described_class.timeline(from: from_time, to: to_time, offset: 1, unit: :hour)

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end
  end

  describe '#initialize' do
    it 'sets time and config' do
      nocturnal = described_class.new(test_time, config: mock_config)

      expect(nocturnal.instance_variable_get(:@time)).to eq(test_time)
      expect(nocturnal.instance_variable_get(:@config)).to eq(mock_config)
    end

    it 'works without config' do
      nocturnal = described_class.new(test_time)

      expect(nocturnal.instance_variable_get(:@time)).to eq(test_time)
      expect(nocturnal.instance_variable_get(:@config)).to be_nil
    end
  end

  describe '#config' do
    it 'returns provided config' do
      nocturnal = described_class.new(test_time, config: mock_config)

      expect(nocturnal.config).to eq(mock_config)
    end

    it 'returns default config when not provided' do
      allow(Trifle::Stats).to receive(:default).and_return(mock_config)
      nocturnal = described_class.new(test_time)

      expect(nocturnal.config).to eq(mock_config)
    end
  end

  # The new Nocturnal class has a different API - these methods don't exist anymore
  # describe '#change' do ... end

  # describe '#second' do ... end

  # describe '#next_second' do ... end

  # describe '#minute' do ... end

  # describe '#next_minute' do ... end

  # describe '#hour' do ... end

  # describe '#next_hour' do ... end

  # describe '#day' do ... end

  # describe '#next_day' do ... end

  # describe '#week' do ... end

  # describe '#next_week' do ... end

  # describe '#days_to_week_start' do ... end

  # describe '#month' do ... end

  # describe '#next_month' do ... end

  # describe '#quarter' do ... end

  # describe '#next_quarter' do ... end

  # describe '#year' do ... end

  # describe '#next_year' do ... end

  describe '#floor' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'floors to hour boundary' do
      result = nocturnal.floor(1, :hour)
      expect(result).to eq(Time.new(2023, 3, 15, 14, 0, 0, 0))
    end

    it 'floors to day boundary' do
      result = nocturnal.floor(1, :day)
      expect(result.hour).to eq(0)
      expect(result.min).to eq(0)
      expect(result.sec).to eq(0)
    end
  end

  describe '#add' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'adds hours' do
      result = nocturnal.add(2, :hour)
      expect(result).to eq(Time.new(2023, 3, 15, 16, 30, 45, 0))
    end

    it 'adds days' do
      result = nocturnal.add(1, :day)
      expect(result).to eq(Time.new(2023, 3, 16, 14, 30, 45, 0))
    end
  end
end