RSpec.describe Trifle::Stats::Designator::Linear do
  describe '#initialize' do
    it 'sets min, max, and step attributes' do
      designator = described_class.new(min: 10, max: 100, step: 20)

      expect(designator.min).to eq(10)
      expect(designator.max).to eq(100)
      expect(designator.step).to eq(20)
    end

    it 'converts step to integer' do
      designator = described_class.new(min: 0, max: 100, step: 25.7)

      expect(designator.step).to eq(25)
    end

    it 'handles string step values' do
      designator = described_class.new(min: 0, max: 100, step: '15')

      expect(designator.step).to eq(15)
    end
  end

  describe '#designate' do
    let(:designator) { described_class.new(min: 10, max: 100, step: 20) }

    context 'when value is below minimum' do
      it 'returns min as string' do
        expect(designator.designate(value: 5)).to eq('10')
        expect(designator.designate(value: 10)).to eq('10')
      end
    end

    context 'when value is above maximum' do
      it 'returns max+ format' do
        expect(designator.designate(value: 150)).to eq('100+')
        expect(designator.designate(value: 101)).to eq('100+')
      end
    end

    context 'when value is within granularity' do
      it 'returns correct bucket for exact step values' do
        expect(designator.designate(value: 11)).to eq('20')
        expect(designator.designate(value: 20)).to eq('20')
        expect(designator.designate(value: 21)).to eq('40')
        expect(designator.designate(value: 40)).to eq('40')
      end

      it 'rounds up to next step boundary' do
        expect(designator.designate(value: 15)).to eq('20')
        expect(designator.designate(value: 25)).to eq('40')
        expect(designator.designate(value: 35)).to eq('40')
        expect(designator.designate(value: 55)).to eq('60')
      end

      it 'handles edge cases near boundaries' do
        expect(designator.designate(value: 19.9)).to eq('20')
        expect(designator.designate(value: 20.1)).to eq('40')
        expect(designator.designate(value: 39.9)).to eq('40')
        expect(designator.designate(value: 40.1)).to eq('60')
      end
    end

    context 'with different step sizes' do
      it 'works with step size 1' do
        designator = described_class.new(min: 0, max: 10, step: 1)
        
        expect(designator.designate(value: 0.5)).to eq('1')
        expect(designator.designate(value: 1.5)).to eq('2')
        expect(designator.designate(value: 2.9)).to eq('3')
      end

      it 'works with step size 50' do
        designator = described_class.new(min: 0, max: 500, step: 50)
        
        expect(designator.designate(value: 25)).to eq('50')
        expect(designator.designate(value: 75)).to eq('100')
        expect(designator.designate(value: 125)).to eq('150')
      end

      it 'works with step size 10' do
        designator = described_class.new(min: 5, max: 95, step: 10)
        
        expect(designator.designate(value: 8)).to eq('10')
        expect(designator.designate(value: 15)).to eq('20')
        expect(designator.designate(value: 23)).to eq('30')
      end
    end

    context 'with negative values' do
      let(:designator) { described_class.new(min: -50, max: 50, step: 25) }

      it 'handles negative minimum' do
        expect(designator.designate(value: -100)).to eq('-50')
        expect(designator.designate(value: -50)).to eq('-50')
      end

      it 'designates negative values correctly' do
        expect(designator.designate(value: -25)).to eq('-25')
        expect(designator.designate(value: -10)).to eq('0')
      end

      it 'handles positive values normally' do
        expect(designator.designate(value: 10)).to eq('25')
        expect(designator.designate(value: 30)).to eq('50')
      end
    end

    context 'with float values' do
      let(:designator) { described_class.new(min: 0.0, max: 10.0, step: 2) }

      it 'handles float inputs' do
        expect(designator.designate(value: 1.5)).to eq('2')
        expect(designator.designate(value: 2.5)).to eq('4')
        expect(designator.designate(value: 3.7)).to eq('4')
      end

      it 'handles very small values' do
        expect(designator.designate(value: 0.1)).to eq('2')
        expect(designator.designate(value: 0.9)).to eq('2')
      end
    end

    context 'edge cases' do
      it 'handles zero step (causes division by zero)' do
        designator = described_class.new(min: 0, max: 100, step: 0)
        
        expect { designator.designate(value: 50) }.to raise_error(ZeroDivisionError)
      end

      it 'handles same min and max' do
        designator = described_class.new(min: 50, max: 50, step: 10)
        
        expect(designator.designate(value: 25)).to eq('50')
        expect(designator.designate(value: 50)).to eq('50')
        expect(designator.designate(value: 75)).to eq('50+')
      end
    end
  end
end