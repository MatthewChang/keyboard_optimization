require 'spec_helper'
require 'rglpk'
require_relative '../MIP'

describe 'and_gate' do
  before :each do
    def genRandomProblem
      @problem = Rglpk::Problem.new
      @problem.name = 'LogicTest'
      @problem.obj.dir = Rglpk::GLP_MAX
      @numCols = Random.new.rand(3..5)

      @vars = @problem.add_cols(@numCols)
      @vars.each do |var|
        var.set_bounds(Rglpk::GLP_DB, 0, 1)
        var.kind = Rglpk::GLP_IV
      end
      @matrix = []
      @problem.obj.coefs = Array.new(@numCols) { rand(-1..1) }
    end

    def randomIndices(range, n)
      (0..range - 1).to_a.shuffle.take(n)
    end
  end

  it 'computes the and' do
    50.times do
      genRandomProblem
      t, v1, v2 = randomIndices(@numCols, 3)
      MIP.and(@problem, @matrix, t, v1, v2)
      @problem.set_matrix(@matrix.flatten)
      @problem.simplex
      @problem.mip
      bools = @vars.map {|e| e.mip_val == 1 }
      expect(bools[t]).to eq((bools[v1]) && (bools[v2]))
    end
  end

  it 'computes an or of arbitraty inputs' do
    50.times do
      genRandomProblem
      numIndices = rand(3..@numCols)
      indices = randomIndices(@numCols,numIndices)
      MIP.or(@problem, @matrix, *indices)
      @problem.set_matrix(@matrix.flatten)
      @problem.simplex
      @problem.mip
      bools = @vars.map {|e| e.mip_val == 1 }
      or_val = indices[1..-1].reduce(false) {|v,e| v || bools[e]}
      expect(bools[indices[0]]).to eq(or_val)
    end
  end
end
