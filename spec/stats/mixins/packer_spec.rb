RSpec.describe Trifle::Stats::Mixins::Packer do
  class PackerWrapper
    include Trifle::Stats::Mixins::Packer
  end

  describe 'Pack' do
    let(:hash_simple) { {a: 1, b: 2, c: 3 } }
    let(:hash_nested) { {a: 1, b: {c: 22, d: 33, e: {f: 444}, g: 55}, h: 6} }
    let(:hash_nested_broken) { {a: 1, b: {c: 22}, 'b.c' => 'err'} }

    it 'packs simple hash' do
      expect(PackerWrapper.pack(hash: hash_simple)).to eq({'a' => 1, 'b' => 2, 'c' => 3})
    end

    it 'packs nested hash' do
      expect(PackerWrapper.pack(hash: hash_nested)).to eq({'a' => 1, 'b.c' => 22, 'b.d' => 33, 'b.e.f' => 444, 'b.g' => 55, 'h' => 6})
    end

    it 'packs nested hash with duplicate nested keys' do
      expect(PackerWrapper.pack(hash: hash_nested_broken)).to eq({'a' => 1, 'b.c' => 'err'})
    end
  end

  describe 'Unpack' do
    let(:hash_simple) { {'a' => 1, 'b' => 2, 'c' => 3} }
    let(:hash_nested) { {'a' => 1, 'b.c' => 22, 'b.d' => 33, 'b.e.f' => 444, 'b.g' => 55, 'h' => 6} }

    it 'unpacks simple hash' do
      expect(PackerWrapper.unpack(hash: hash_simple)).to eq({'a' => 1, 'b' => 2, 'c' => 3})
    end

    it 'unpacks nested hash' do
      expect(PackerWrapper.unpack(hash: hash_nested)).to eq({'a' => 1, 'b' => {'c' => 22, 'd' => 33, 'e' => {'f' => 444}, 'g' => 55}, 'h' => 6})
    end
  end

  describe 'Normalize' do
    let(:symbol_hash) { {a: 1, b: 2, c: 3} }
    let(:string_hash) { {'a' => 1, 'b' => 2, 'c' => 3} }

    it 'normalize symbol hash' do
      expect(PackerWrapper.normalize(symbol_hash)).to eq({'a' => 1, 'b' => 2, 'c' => 3})
    end

    it 'normalize string hash' do
      expect(PackerWrapper.normalize(string_hash)).to eq({'a' => 1, 'b' => 2, 'c' => 3})
    end
  end
end
