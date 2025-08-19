RSpec.describe Trifle::Stats::Configuration do
  let(:configuration) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(configuration.instance_variable_get(:@granularities)).to eq([:second, :minute, :hour, :day, :week, :month, :quarter, :year])
      expect(configuration.beginning_of_week).to eq(:monday)
      expect(configuration.time_zone).to eq('GMT')
      expect(configuration.designator).to be_nil
    end
  end

  describe '#driver=' do
    let(:mock_driver) { instance_double(Trifle::Stats::Driver::Process) }

    it 'sets the driver' do
      configuration.driver = mock_driver
      
      expect(configuration.instance_variable_get(:@driver)).to eq(mock_driver)
    end
  end

  describe '#driver' do
    let(:mock_driver) { instance_double(Trifle::Stats::Driver::Process) }

    context 'when driver is set' do
      it 'returns the driver' do
        configuration.driver = mock_driver
        
        expect(configuration.driver).to eq(mock_driver)
      end
    end

    context 'when driver is not set' do
      it 'raises DriverNotFound error' do
        expect { configuration.driver }.to raise_error(Trifle::Stats::DriverNotFound)
      end
    end
  end

  describe '#track_granularities=' do
    it 'sets track_granularities' do
      configuration.track_granularities = [:hour, :day]
      
      expect(configuration.track_granularities).to eq([:hour, :day])
    end
  end

  describe '#time_zone=' do
    it 'sets time_zone' do
      configuration.time_zone = 'UTC'
      
      expect(configuration.time_zone).to eq('UTC')
    end
  end

  describe '#beginning_of_week=' do
    it 'sets beginning_of_week' do
      configuration.beginning_of_week = :sunday
      
      expect(configuration.beginning_of_week).to eq(:sunday)
    end
  end

  describe '#designator=' do
    let(:mock_designator) { instance_double(Trifle::Stats::Designator::Linear) }

    it 'sets designator' do
      configuration.designator = mock_designator
      
      expect(configuration.designator).to eq(mock_designator)
    end
  end

  describe '#tz' do
    context 'with valid timezone' do
      it 'returns TZInfo timezone object' do
        configuration.time_zone = 'Europe/London'
        
        result = configuration.tz
        
        expect(result).to be_a(TZInfo::Timezone)
        expect(result.identifier).to eq('Europe/London')
      end
    end

    context 'with GMT timezone' do
      it 'returns GMT timezone object' do
        configuration.time_zone = 'GMT'
        
        result = configuration.tz
        
        expect(result).to be_a(TZInfo::Timezone)
        expect(result.identifier).to eq('GMT')
      end
    end

    context 'with invalid timezone' do
      it 'prints warning and defaults to GMT' do
        configuration.time_zone = 'Invalid/Timezone'
        
        expect { configuration.tz }.to output(/Trifle.*Invalid.*Timezone.*GMT/).to_stdout
        
        result = configuration.tz
        expect(result.identifier).to eq('GMT')
      end
    end

    context 'with UTC timezone' do
      it 'returns UTC timezone object' do
        configuration.time_zone = 'UTC'
        
        result = configuration.tz
        
        expect(result).to be_a(TZInfo::Timezone)
        expect(result.identifier).to eq('UTC')
      end
    end
  end

  describe '#granularities' do
    context 'when track_granularities is not set' do
      it 'returns all default granularities' do
        expect(configuration.granularities).to eq([:second, :minute, :hour, :day, :week, :month, :quarter, :year])
      end
    end

    context 'when track_granularities is empty array' do
      it 'returns all default granularities' do
        configuration.track_granularities = []
        
        expect(configuration.granularities).to eq([:second, :minute, :hour, :day, :week, :month, :quarter, :year])
      end
    end

    context 'when track_granularities is nil' do
      it 'returns all default granularities' do
        configuration.track_granularities = nil
        
        expect(configuration.granularities).to eq([:second, :minute, :hour, :day, :week, :month, :quarter, :year])
      end
    end

    context 'when track_granularities is set' do
      it 'returns intersection of default granularities and track_granularities' do
        configuration.track_granularities = [:hour, :day, :month, :invalid_granularity]
        
        expect(configuration.granularities).to eq([:hour, :day, :month])
      end
    end

    context 'when track_granularities contains only valid granularities' do
      it 'returns only specified granularities in original order' do
        configuration.track_granularities = [:day, :hour, :year]
        
        expect(configuration.granularities).to eq([:hour, :day, :year])
      end
    end

    context 'when track_granularities contains no valid granularities' do
      it 'returns empty array' do
        configuration.track_granularities = [:invalid1, :invalid2]
        
        expect(configuration.granularities).to eq([])
      end
    end

    context 'when track_granularities contains duplicates' do
      it 'returns unique granularities' do
        configuration.track_granularities = [:hour, :day, :hour, :day]
        
        expect(configuration.granularities).to eq([:hour, :day])
      end
    end
  end

  describe '#blank?' do
    let(:configuration) { described_class.new }

    context 'with objects that respond to empty?' do
      it 'returns true for empty array' do
        expect(configuration.send(:blank?, [])).to be true
      end

      it 'returns false for non-empty array' do
        expect(configuration.send(:blank?, [:hour])).to be false
      end

      it 'returns true for empty string' do
        expect(configuration.send(:blank?, '')).to be true
      end

      it 'returns false for non-empty string' do
        expect(configuration.send(:blank?, 'test')).to be false
      end

      it 'returns true for empty hash' do
        expect(configuration.send(:blank?, {})).to be true
      end

      it 'returns false for non-empty hash' do
        expect(configuration.send(:blank?, { key: 'value' })).to be false
      end
    end

    context 'with objects that do not respond to empty?' do
      it 'returns true for nil' do
        expect(configuration.send(:blank?, nil)).to be true
      end

      it 'returns true for false' do
        expect(configuration.send(:blank?, false)).to be true
      end

      it 'returns false for true' do
        expect(configuration.send(:blank?, true)).to be false
      end

      it 'returns false for numbers' do
        expect(configuration.send(:blank?, 0)).to be false
        expect(configuration.send(:blank?, 42)).to be false
      end

      it 'returns false for objects' do
        expect(configuration.send(:blank?, Object.new)).to be false
      end
    end
  end
end