require 'rglpk'

module MIP
  def self.and(problem,matrix,target,v1,v2)
    numCols = problem.cols.count
    rows = problem.add_rows(3)
    #v1 > target
    rows[0].set_bounds(Rglpk::GLP_UP,0,0)
    newRow = [0]*numCols
    newRow[v1] = -1
    newRow[target] = 1
    matrix << newRow
    #v2 > target
    rows[1].set_bounds(Rglpk::GLP_UP,0,0)
    newRow = [0]*numCols
    newRow[v2] = -1
    newRow[target] = 1
    matrix << newRow
    #target >= v1 + v2 -1
    rows[2].set_bounds(Rglpk::GLP_UP,0,1)
    newRow = [0]*numCols
    newRow[v1] = 1
    newRow[v2] = 1
    newRow[target] = -1
    matrix << newRow
  end
end
