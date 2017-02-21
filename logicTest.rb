require 'rglpk'

p = Rglpk::Problem.new
p.name = 'LogicTest'
p.obj.dir = Rglpk::GLP_MAX

matrix = []

# three binary columns, the last column should be the and of the first two  
cols = p.add_cols(3)
cols.each do |col|
  col.set_bounds(Rglpk::GLP_DB, 0, 1)
  col.kind = Rglpk::GLP_IV
end

p.obj.coefs = [-1, -1, 0]

# rules
# key must be in 1 column
rows = p.add_rows(3)
rows[0].set_bounds(Rglpk::GLP_UP,0,0)
matrix << [-1,0,1]
rows[1].set_bounds(Rglpk::GLP_UP,0,0)
matrix << [0,-1,1]
rows[2].set_bounds(Rglpk::GLP_UP,0,1)
matrix << [1,1,-1]

p.set_matrix(matrix.flatten)
puts matrix.to_a.map(&:inspect)
p.simplex
p.mip 

z = p.obj.mip
puts z
puts cols[0].mip_val
puts cols[1].mip_val
puts cols[2].mip_val

