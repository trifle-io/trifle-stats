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

    it 'generates timeline for hour range' do
      result = described_class.timeline(from: from_time, to: to_time, range: :hour, config: mock_config)

      expect(result).to eq([
        Time.parse('2023-03-15 10:00:00 UTC'),
        Time.parse('2023-03-15 11:00:00 UTC'),
        Time.parse('2023-03-15 12:00:00 UTC')
      ])
    end

    it 'generates timeline for day range' do
      from_day = Time.parse('2023-03-15 00:00:00 UTC')
      to_day = Time.parse('2023-03-17 00:00:00 UTC')

      result = described_class.timeline(from: from_day, to: to_day, range: :day, config: mock_config)

      expect(result).to eq([
        Time.parse('2023-03-15 00:00:00 UTC'),
        Time.parse('2023-03-16 00:00:00 UTC'),
        Time.parse('2023-03-17 00:00:00 UTC')
      ])
    end

    it 'handles single point timeline' do
      result = described_class.timeline(from: from_time, to: from_time, range: :hour, config: mock_config)

      expect(result).to eq([Time.parse('2023-03-15 10:00:00 UTC')])
    end

    it 'uses default config when not provided' do
      allow(Trifle::Stats).to receive(:default).and_return(mock_config)

      result = described_class.timeline(from: from_time, to: to_time, range: :hour)

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end
  end

  describe '#initialize' do
    it 'sets time and config' do
      nocturnal = described_class.new(test_time, config: mock_config)

      expect(nocturnal.instance_variable_get(:@at)).to eq(test_time)
      expect(nocturnal.instance_variable_get(:@config)).to eq(mock_config)
    end

    it 'works without config' do
      nocturnal = described_class.new(test_time)

      expect(nocturnal.instance_variable_get(:@at)).to eq(test_time)
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

  describe '#change' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'changes specified time components' do
      result = nocturnal.change(hour: 10, minute: 15)

      expect(result).to eq(Time.new(2023, 3, 15, 10, 15, 0, 0))
    end

    it 'keeps unchanged components from original time' do
      result = nocturnal.change(minute: 0)

      expect(result).to eq(Time.new(2023, 3, 15, 14, 0, 0, 0))
    end

    it 'uses config timezone offset' do
      allow(mock_tz).to receive(:utc_offset).and_return(3600) # +1 hour
      
      result = nocturnal.change(hour: 12)

      expect(result).to eq(Time.new(2023, 3, 15, 12, 30, 0, 3600))
    end
  end

  describe '#second' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns time preserving exact second' do
      result = nocturnal.second

      expect(result).to eq(Time.new(2023, 3, 15, 14, 30, 45, 0))
    end
  end

  describe '#next_second' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns next second boundary' do
      result = nocturnal.next_second

      expect(result).to eq(Time.new(2023, 3, 15, 14, 30, 46, 0))
    end
  end

  describe '#minute' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns time with seconds reset to 0' do
      result = nocturnal.minute

      expect(result).to eq(Time.new(2023, 3, 15, 14, 30, 0, 0))
    end
  end

  describe '#next_minute' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns next minute boundary' do
      result = nocturnal.next_minute

      expect(result).to eq(Time.new(2023, 3, 15, 14, 31, 0, 0))
    end
  end

  describe '#hour' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns hour with minutes and seconds reset' do
      result = nocturnal.hour

      expect(result).to eq(Time.new(2023, 3, 15, 14, 0, 0, 0))
    end
  end

  describe '#next_hour' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns next hour boundary' do
      result = nocturnal.next_hour

      expect(result).to eq(Time.new(2023, 3, 15, 15, 0, 0, 0))
    end
  end

  describe '#day' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns beginning of day' do
      result = nocturnal.day

      expect(result).to eq(Time.new(2023, 3, 15, 0, 0, 0, 0))
    end
  end

  describe '#next_day' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns beginning of next day' do
      result = nocturnal.next_day

      expect(result).to eq(Time.new(2023, 3, 16, 0, 0, 0, 0))
    end
  end

  describe '#week' do
    context 'with monday as beginning of week' do
      let(:nocturnal) { described_class.new(test_time, config: mock_config) } # Wednesday

      it 'returns beginning of week (Monday)' do
        result = nocturnal.week

        expect(result.year).to eq(2023)
        expect(result.month).to eq(3)
        expect(result.day).to eq(13) # Monday
        expect(result.hour).to eq(0)
        expect(result.min).to eq(0)
        expect(result.sec).to eq(0)
      end
    end

    context 'with sunday as beginning of week' do
      let(:nocturnal) { described_class.new(test_time, config: mock_config) }

      before do
        allow(mock_config).to receive(:beginning_of_week).and_return(:sunday)
      end

      it 'returns beginning of week (Sunday)' do
        result = nocturnal.week

        expect(result.year).to eq(2023)
        expect(result.month).to eq(3)
        expect(result.day).to eq(12) # Sunday
        expect(result.hour).to eq(0)
        expect(result.min).to eq(0)
        expect(result.sec).to eq(0)
      end
    end

    context 'when current day is beginning of week' do
      let(:monday_time) { Time.parse('2023-03-13 14:30:45 UTC') } # Monday
      let(:nocturnal) { described_class.new(monday_time, config: mock_config) }

      it 'returns current day beginning' do
        result = nocturnal.week

        expect(result.year).to eq(2023)
        expect(result.month).to eq(3)
        expect(result.day).to eq(13) # Monday
        expect(result.hour).to eq(0)
        expect(result.min).to eq(0)
        expect(result.sec).to eq(0)
      end
    end
  end

  describe '#next_week' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns beginning of next week' do
      result = nocturnal.next_week

      expect(result.year).to eq(2023)
      expect(result.month).to eq(3)
      expect(result.day).to eq(20) # Next Monday
      expect(result.hour).to eq(0)
      expect(result.min).to eq(0)
      expect(result.sec).to eq(0)
    end
  end

  describe '#days_to_week_start' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) } # Wednesday (wday=3)

    context 'with monday as beginning of week' do
      it 'returns days from monday' do
        result = nocturnal.days_to_week_start

        expect(result).to eq(2) # Wednesday is 2 days from Monday
      end
    end

    context 'with sunday as beginning of week' do
      before do
        allow(mock_config).to receive(:beginning_of_week).and_return(:sunday)
      end

      it 'returns days from sunday' do
        result = nocturnal.days_to_week_start

        expect(result).to eq(3) # Wednesday is 3 days from Sunday
      end
    end

    context 'with saturday as beginning of week' do
      before do
        allow(mock_config).to receive(:beginning_of_week).and_return(:saturday)
      end

      it 'returns days from saturday' do
        result = nocturnal.days_to_week_start

        expect(result).to eq(4) # Wednesday is 4 days from Saturday
      end
    end
  end

  describe '#month' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns beginning of month' do
      result = nocturnal.month

      expect(result).to eq(Time.new(2023, 3, 1, 0, 0, 0, 0))
    end
  end

  describe '#next_month' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns beginning of next month' do
      result = nocturnal.next_month

      expect(result).to eq(Time.new(2023, 4, 1, 0, 0, 0, 0))
    end
  end

  describe '#quarter' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) } # March

    it 'returns beginning of quarter (Q1: Jan-Mar)' do
      result = nocturnal.quarter

      expect(result).to eq(Time.new(2023, 1, 1, 0, 0, 0, 0))
    end

    context 'in Q2 (Apr-Jun)' do
      let(:q2_time) { Time.parse('2023-05-15 14:30:45 UTC') }
      let(:nocturnal) { described_class.new(q2_time, config: mock_config) }

      it 'returns beginning of Q2' do
        result = nocturnal.quarter

        expect(result).to eq(Time.new(2023, 4, 1, 0, 0, 0, 0))
      end
    end

    context 'in Q3 (Jul-Sep)' do
      let(:q3_time) { Time.parse('2023-08-15 14:30:45 UTC') }
      let(:nocturnal) { described_class.new(q3_time, config: mock_config) }

      it 'returns beginning of Q3' do
        result = nocturnal.quarter

        expect(result).to eq(Time.new(2023, 7, 1, 0, 0, 0, 0))
      end
    end

    context 'in Q4 (Oct-Dec)' do
      let(:q4_time) { Time.parse('2023-11-15 14:30:45 UTC') }
      let(:nocturnal) { described_class.new(q4_time, config: mock_config) }

      it 'returns beginning of Q4' do
        result = nocturnal.quarter

        expect(result).to eq(Time.new(2023, 10, 1, 0, 0, 0, 0))
      end
    end
  end

  describe '#next_quarter' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) } # March (Q1)

    it 'returns beginning of next quarter' do
      result = nocturnal.next_quarter

      expect(result).to eq(Time.new(2023, 4, 1, 0, 0, 0, 0)) # Q2
    end
  end

  describe '#year' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns beginning of year' do
      result = nocturnal.year

      expect(result).to eq(Time.new(2023, 1, 1, 0, 0, 0, 0))
    end
  end

  describe '#next_year' do
    let(:nocturnal) { described_class.new(test_time, config: mock_config) }

    it 'returns beginning of next year' do
      result = nocturnal.next_year

      expect(result).to eq(Time.new(2024, 1, 1, 0, 0, 0, 0))
    end
  end
end