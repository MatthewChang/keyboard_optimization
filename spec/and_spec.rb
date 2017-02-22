require 'spec_helper'
require 'rglpk'
require_relative '../MIP'

describe 'and_gate' do
  before :each do
    def genRandomProblem()
      @problem = Rglpk::Problem.new
      @problem.name = 'LogicTest'
      @problem.obj.dir = Rglpk::GLP_MAX
      @numCols = 3#Random.new.rand(20)
      # three binary columns, the last column should be the and of the first two  
      @vars = @problem.add_cols(@numCols)
      @vars.each do |var|
        var.set_bounds(Rglpk::GLP_DB, 0, 1)
        var.kind = Rglpk::GLP_IV
      end
      @matrix = []
      @problem.obj.coefs = Array.new(@numCols) {rand(-1..1)}
    end
  end
  it 'computes the and' do
    50.times do 
      genRandomProblem()
      MIP.and(@problem,@matrix,0,1,2)
      @problem.set_matrix(@matrix.flatten)
      @problem.simplex
      @problem.mip 
      expect(@vars[0].mip_val == 1).to eq((@vars[1].mip_val == 1) && (@vars[2].mip_val == 1))
    end
  end
end
