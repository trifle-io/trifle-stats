RSpec.describe Trifle::Stats::Designator::Geometric do
  describe '#initialize' do
    it 'sets min and max attributes' do
      designator = described_class.new(min: 1, max: 1000)

      expect(designator.min).to eq(1)
      expect(designator.max).to eq(1000)
    end

    it 'converts negative min to 0' do
      designator = described_class.new(min: -5, max: 100)

      expect(designator.min).to eq(0)
    end

    it 'preserves positive min values' do
      designator = described_class.new(min: 10, max: 1000)

      expect(designator.min).to eq(10)
    end

    it 'preserves zero min value' do
      designator = described_class.new(min: 0, max: 100)

      expect(designator.min).to eq(0)
    end
  end

  describe '#designate' do
    let(:designator) { described_class.new(min: 0.001, max: 1000) }

    context 'when value is below minimum' do
      it 'returns min as float string' do
        expect(designator.designate(value: 0.0005)).to eq('0.001')
        expect(designator.designate(value: 0.001)).to eq('0.001')
      end
    end

    context 'when value is above maximum' do
      it 'returns max+ format as float' do
        expect(designator.designate(value: 1500)).to eq('1000.0+')
        expect(designator.designate(value: 1001)).to eq('1000.0+')
      end
    end

    context 'when value is greater than 1' do
      it 'returns power of 10 based on number length' do
        expect(designator.designate(value: 2)).to eq('10.0')    # 1 digit -> 10^1
        expect(designator.designate(value: 9)).to eq('10.0')    # 1 digit -> 10^1
        expect(designator.designate(value: 12)).to eq('100.0')  # 2 digits -> 10^2
        expect(designator.designate(value: 99)).to eq('100.0')  # 2 digits -> 10^2
        expect(designator.designate(value: 123)).to eq('1000.0') # 3 digits -> 10^3
        expect(designator.designate(value: 999)).to eq('1000.0') # 3 digits -> 10^3
      end

      it 'handles float values greater than 1' do
        expect(designator.designate(value: 2.5)).to eq('10.0')   # floor=2, 1 digit
        expect(designator.designate(value: 15.7)).to eq('100.0') # floor=15, 2 digits
        expect(designator.designate(value: 150.9)).to eq('1000.0') # floor=150, 3 digits
      end
    end

    context 'when value is between 0.1 and 1' do
      it 'returns 1.0' do
        expect(designator.designate(value: 0.9)).to eq('1.0')
        expect(designator.designate(value: 0.5)).to eq('1.0')
        expect(designator.designate(value: 0.11)).to eq('1.0')
      end
    end

    context 'when value is less than 0.1 and above min' do
      it 'calculates inverse power of 10 based on leading zeros' do
        expect(designator.designate(value: 0.01)).to eq('0.1')     # 1 leading zero -> 1/10^1
        expect(designator.designate(value: 0.05)).to eq('0.1')     # 1 leading zero -> 1/10^1
        expect(designator.designate(value: 0.007)).to eq('0.01')   # 2 leading zeros -> 1/10^2
        expect(designator.designate(value: 0.009)).to eq('0.01')   # 2 leading zeros -> 1/10^2
      end
    end

    context 'with different min/max ranges' do
      it 'works with min=0' do
        designator = described_class.new(min: 0, max: 100)
        
        expect(designator.designate(value: -5)).to eq('0.0')
        expect(designator.designate(value: 0)).to eq('0.0')
        expect(designator.designate(value: 5)).to eq('10.0')
      end

      it 'works with higher min value' do
        designator = described_class.new(min: 10, max: 10000)
        
        expect(designator.designate(value: 5)).to eq('10.0')
        expect(designator.designate(value: 10)).to eq('10.0')
        expect(designator.designate(value: 50)).to eq('100.0')
      end

      it 'works with float min/max' do
        designator = described_class.new(min: 0.5, max: 500.0)
        
        expect(designator.designate(value: 0.1)).to eq('0.5')
        expect(designator.designate(value: 0.5)).to eq('0.5')
        expect(designator.designate(value: 600)).to eq('500.0+')
      end
    end

    context 'edge cases' do
      it 'handles exactly 1.0' do
        expect(designator.designate(value: 1.0)).to eq('1.0')
      end

      it 'handles exactly 0.1 (triggers string parsing bug)' do
        expect { designator.designate(value: 0.1) }.to raise_error(NoMethodError)
      end

      it 'handles zero (below min)' do
        expect(designator.designate(value: 0)).to eq('0.001')
      end

      it 'handles negative values (treated as below min)' do
        expect(designator.designate(value: -10)).to eq('0.001')
        expect(designator.designate(value: -0.5)).to eq('0.001')
      end

      it 'handles very large numbers (above max)' do
        expect(designator.designate(value: 12345)).to eq('1000.0+') # above max=1000
      end

      it 'handles very small numbers (below min)' do
        expect(designator.designate(value: 0.00001)).to eq('0.001') # below min
      end
    end

    context 'same min and max' do
      let(:designator) { described_class.new(min: 50, max: 50) }

      it 'handles values below range' do
        expect(designator.designate(value: 25)).to eq('50.0')
      end

      it 'handles values at boundary' do
        expect(designator.designate(value: 50)).to eq('50.0')
      end

      it 'handles values above range' do
        expect(designator.designate(value: 75)).to eq('50.0+')
      end
    end
  end
end