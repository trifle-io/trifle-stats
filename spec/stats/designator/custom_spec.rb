RSpec.describe Trifle::Stats::Designator::Custom do
  describe '#initialize' do
    it 'sets buckets attribute and sorts them' do
      designator = described_class.new(buckets: [100, 50, 10, 200])

      expect(designator.buckets).to eq([10, 50, 100, 200])
    end

    it 'handles already sorted buckets' do
      designator = described_class.new(buckets: [1, 5, 10, 25])

      expect(designator.buckets).to eq([1, 5, 10, 25])
    end

    it 'handles single bucket' do
      designator = described_class.new(buckets: [50])

      expect(designator.buckets).to eq([50])
    end

    it 'handles duplicate values by keeping them' do
      designator = described_class.new(buckets: [10, 20, 10, 30, 20])

      expect(designator.buckets).to eq([10, 10, 20, 20, 30])
    end
  end

  describe '#designate' do
    let(:designator) { described_class.new(buckets: [10, 50, 100, 500]) }

    context 'when value is below first bucket' do
      it 'returns first bucket as string' do
        expect(designator.designate(value: 5)).to eq('10')
        expect(designator.designate(value: 10)).to eq('10')
      end
    end

    context 'when value is above last bucket' do
      it 'returns last bucket+ format' do
        expect(designator.designate(value: 600)).to eq('500+')
        expect(designator.designate(value: 501)).to eq('500+')
      end
    end

    context 'when value is within buckets granularity' do
      it 'returns the first bucket that value.ceil is less than' do
        expect(designator.designate(value: 11)).to eq('50')   # ceil(11) = 11, first bucket > 11 is 50
        expect(designator.designate(value: 25)).to eq('50')   # ceil(25) = 25, first bucket > 25 is 50
        expect(designator.designate(value: 49)).to eq('50')   # ceil(49) = 49, first bucket > 49 is 50
        expect(designator.designate(value: 50)).to eq('100')  # ceil(50) = 50, first bucket > 50 is 100
        expect(designator.designate(value: 75)).to eq('100')  # ceil(75) = 75, first bucket > 75 is 100
        expect(designator.designate(value: 100)).to eq('500') # ceil(100) = 100, first bucket > 100 is 500
      end

      it 'handles float values by ceiling them' do
        expect(designator.designate(value: 10.1)).to eq('50')  # ceil(10.1) = 11, first bucket > 11 is 50
        expect(designator.designate(value: 49.9)).to eq('100') # ceil(49.9) = 50, first bucket > 50 is 100
        expect(designator.designate(value: 50.1)).to eq('100') # ceil(50.1) = 51, first bucket > 51 is 100
        expect(designator.designate(value: 99.1)).to eq('500') # ceil(99.1) = 100, first bucket > 100 is 500
        expect(designator.designate(value: 100.1)).to eq('500') # ceil(100.1) = 101, first bucket > 101 is 500
      end
    end

    context 'with different bucket configurations' do
      it 'works with single bucket' do
        designator = described_class.new(buckets: [25])
        
        expect(designator.designate(value: 10)).to eq('25')
        expect(designator.designate(value: 26)).to eq('25+')  # 26 > 25 (last bucket)
        expect(designator.designate(value: 30)).to eq('25+')  # 30 > 25 (last bucket)
      end

      it 'works with two buckets' do
        designator = described_class.new(buckets: [20, 80])
        
        expect(designator.designate(value: 15)).to eq('20')
        expect(designator.designate(value: 20)).to eq('20')
        expect(designator.designate(value: 21)).to eq('80')
        expect(designator.designate(value: 81)).to eq('80+')  # 81 > 80 (last bucket)
        expect(designator.designate(value: 100)).to eq('80+') # 100 > 80 (last bucket)
      end

      it 'works with many small incremental buckets' do
        designator = described_class.new(buckets: [1, 2, 3, 4, 5])
        
        expect(designator.designate(value: 0.5)).to eq('1')
        expect(designator.designate(value: 1)).to eq('1')
        expect(designator.designate(value: 1.1)).to eq('3')  # ceil(1.1)=2, first bucket > 2 is 3
        expect(designator.designate(value: 2.9)).to eq('4')  # ceil(2.9)=3, first bucket > 3 is 4  
        expect(designator.designate(value: 4.1)).to eq('')   # ceil(4.1)=5, no bucket > 5, so nil.to_s = ""
        expect(designator.designate(value: 5.1)).to eq('5+') # 5.1 > 5 (last bucket)
      end

      it 'works with unsorted input buckets' do
        designator = described_class.new(buckets: [500, 10, 100, 50])
        
        expect(designator.designate(value: 5)).to eq('10')
        expect(designator.designate(value: 25)).to eq('50')
        expect(designator.designate(value: 75)).to eq('100')
        expect(designator.designate(value: 250)).to eq('500')
        expect(designator.designate(value: 600)).to eq('500+')
      end
    end

    context 'edge cases' do
      it 'handles zero value' do
        expect(designator.designate(value: 0)).to eq('10')
      end

      it 'handles negative values' do
        expect(designator.designate(value: -5)).to eq('10')
        expect(designator.designate(value: -100)).to eq('10')
      end

      it 'handles very large values' do
        expect(designator.designate(value: 999999)).to eq('500+')
      end

      it 'handles exact bucket boundary values' do
        expect(designator.designate(value: 10)).to eq('10')   # exactly first bucket
        expect(designator.designate(value: 50)).to eq('100')  # exactly middle bucket
        expect(designator.designate(value: 501)).to eq('500+') # 501 > 500 (last bucket)
      end
    end

    context 'with duplicate buckets' do
      let(:designator) { described_class.new(buckets: [10, 10, 50, 50, 100]) }

      it 'handles duplicate buckets correctly' do
        expect(designator.designate(value: 5)).to eq('10')
        expect(designator.designate(value: 10)).to eq('10')
        expect(designator.designate(value: 11)).to eq('50')  # ceil(11)=11, first bucket > 11 is 50
        expect(designator.designate(value: 25)).to eq('50')
        expect(designator.designate(value: 75)).to eq('100')
        expect(designator.designate(value: 150)).to eq('100+')
      end
    end

    context 'with float buckets' do
      let(:designator) { described_class.new(buckets: [1.5, 5.5, 10.0]) }

      it 'handles float bucket values' do
        expect(designator.designate(value: 1.0)).to eq('1.5')
        expect(designator.designate(value: 1.5)).to eq('1.5')
        expect(designator.designate(value: 2.0)).to eq('5.5')
        expect(designator.designate(value: 5.5)).to eq('10.0')
        expect(designator.designate(value: 8.0)).to eq('10.0')
        expect(designator.designate(value: 10.1)).to eq('10.0+')
      end
    end
  end
end