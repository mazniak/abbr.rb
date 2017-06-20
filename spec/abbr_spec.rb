# see spec_helper.rb for fixture definitions

RSpec.describe Abbr do
  context 'abbr_init(*abbr_args, &blk)' do
    it 'defines getters for each abbr_arg' do
      expect(XPlusOne.instance_methods).to include(:x)
      expect(YPlusOne.instance_methods).to include(:y)
    end

    it 'undefines any inherited abbr_args' do
      expect(MissingNPlusOne.instance_methods).not_to include(:n)
    end
  end

  context '#new(*args)' do
    let(:x) { XPlusOne.new(0) }
    let(:y) { YPlusOne.new(1) }
    let(:missing_n) { MissingNPlusOne.new(9) }
    let(:x_effects) { XPlusOneTracksMemo.new(0) }

    it 'exposes abbr_args values through getter methods' do
      expect(x.n).to eq(0)
      expect(y.n).to eq(1)

      expect(x.to_i).to eq(1)
      expect(y.to_i).to eq(2)
    end

    it 'does not respond to any ancestor abbr_args getters' do
      expect { missing_n.to_i }.to raise_error(NameError)
      expect { missing_n.n }.to raise_error(NameError)
    end

    it 'sets default abbr_args' do
      expect(x_effects.memo_output).to be_a(Array)
    end

    it 'lazily evaluates let getters (once at most per instance)' do
      expect(x_effects.memo_output).to be_empty
      x_effects.memo!
      x_effects.memo!
      x_effects.memo!
      expect(x_effects.memo_output).to eq([ x_effects.memo! ])
    end
  end
end