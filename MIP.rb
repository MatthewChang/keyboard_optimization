require 'rglpk'

module MIP
  def self.and(problem, matrix, target, v1, v2)
    numCols = problem.cols.count
    rows = problem.add_rows(3)
    # v1 > target
    rows[0].set_bounds(Rglpk::GLP_UP, 0, 0)
    newRow = [0] * numCols
    newRow[v1] = -1
    newRow[target] = 1
    matrix << newRow
    # v2 > target
    rows[1].set_bounds(Rglpk::GLP_UP, 0, 0)
    newRow = [0] * numCols
    newRow[v2] = -1
    newRow[target] = 1
    matrix << newRow
    # target >= v1 + v2 -1
    rows[2].set_bounds(Rglpk::GLP_UP, 0, 1)
    newRow = [0] * numCols
    newRow[v1] = 1
    newRow[v2] = 1
    newRow[target] = -1
    matrix << newRow
  end

  def self.or(problem, matrix, target, *locations)
    numCols = problem.cols.count
    rows = problem.add_rows(locations.count + 1)

    # v1 > target
    # t >= X_i for all i
    locations.each_with_index do |e, i|
      rows[i].set_bounds(Rglpk::GLP_LO, 0, 0)
      newRow = [0] * numCols
      newRow[e] = -1
      newRow[target] = 1
      matrix << newRow
    end

    # t <= sum(x_1, x_2, x_3 ... x_n) + 0.1
    rows[-1].set_bounds(Rglpk::GLP_UP, 0, 0.1)
    newRow = [0] * numCols
    locations.each { |e| newRow[e] = -1 }
    newRow[target] = 1
    matrix << newRow
  end

  def self.keyPairIndexGenerator(numKeys)
    ->(k1, k2) do
      (0..(numKeys-1)).to_a.combination(2).to_a.index([k1, k2])
    end
  end

  def self.H_generator(numKeys, numCols)
    keyPairCount = numKeys * (numKeys - 1) / 2

    keyPairIndex = keyPairIndexGenerator(numKeys)

    ->(k1, k2, col) do
      (col * keyPairCount) + keyPairIndex.call(k1, k2)
    end
  end
end
