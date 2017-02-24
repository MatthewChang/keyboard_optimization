require 'spec_helper'
require 'rglpk'
require_relative '../MIP'

describe 'index functions' do
  it 'computes indicies for H_ijc' do
    offset = 9
    H = MIP.H_generator(20, 8, offset)
    indices = []
    for k1 in 0..19 do
      for k2 in (k1 + 1)..19 do
        for c in 0..7 do
          indices << H.call(k1, k2, c)
        end
      end
    end
    expect(indices).to match_array (offset..(20 * 19 / 2 * 8)-1+offset).to_a
  end

  it 'computes continuous key combination indices' do
    K = MIP.keyPairIndexGenerator(40)
    indices = []
    for k1 in 0..39 do
      for k2 in (k1 + 1)..39 do
        indices << K.call(k1, k2)
      end
    end
    puts indices.count
    expect(indices).to match_array (0..(40*39/2)-1).to_a
  end
end
