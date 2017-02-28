require 'CSV'
require 'byebug'
require 'rglpk'
require_relative './MIP'

def parse_letter(letter)
  letter = letter.downcase
  return nil if ['/', "'", '-'].include? letter
  letter
end
letter_frequency = Hash.new(0)
$collision_frequency = {}
CSV.foreach('./words.csv') do |row|
  next if row[0] == 'Rank'
  _, word, _, frequency, = row
  len = word.length
  for i in 0..len - 1 do
    letter = parse_letter(word[i])
    next_letter = i < len - 1 ? parse_letter(word[i + 1]) : nil
    next unless letter
    letter_frequency[letter] += frequency.to_i
    next unless next_letter
    $collision_frequency[letter] = Hash.new(0) unless $collision_frequency[letter]
    $collision_frequency[letter][next_letter] += frequency.to_i
  end
end
# puts letter_frequency.to_a
order = letter_frequency.to_a.sort_by { |e| e[1] }
column = %w(q a z)
qwerty = [%w(q a z), %w(w s x), %w(e d c), %w(r f v), %w(t g b), %w(y h n), %w(u j m), %w(i k), %w(o l), %w(p)]
qwerty_adjusted = [%w(q a z), %w(w s x), %w(e d c), %w(r f v), %w(t g b), %w(y h n), %w(u j m), %w(i k o), %w(l), %w(p)]
colemak = [%w(q a z), %w(w r x), %w(f s c), %w(p t v), %w(g d b), %w(j h k), %w(l n m), %w(u e), %w(y i), %w(o)]
dvorak = [%w(a), %w(o q), %w(e j), %w(p u k), %w(y i k), %w(f d b), %w(g h m), %w(c t w), %w(r n v), %w(l s z)]

$total_keys = letter_frequency.to_a.reduce(0) { |v, e| v + e[1] }

def badness_frequency(column)
  bad = 0
  column.each do |l1|
    column.each do |l2|
      next if l1 == l2
      bad += $collision_frequency[l1][l2] || 0
    end
  end
  bad
end

def total_badness_frequency(keyboard)
  keyboard.reduce(0) { |v, e| v + badness_frequency(e) }
end

def incPos(index, keyboard)
  col, row = index
  if keyboard[col].count == row + 1
    [col + 1, 0]
  else
    [col, row + 1]
  end
end

def swapped(keyboard, p1, p2)
  new_keyboard = keyboard.dup
  new_keyboard[p1[0]] = keyboard[p1[0]].dup
  new_keyboard[p2[0]] = keyboard[p2[0]].dup
  temp = new_keyboard[p1[0]][p1[1]]
  new_keyboard[p1[0]][p1[1]] = new_keyboard[p2[0]][p2[1]]
  new_keyboard[p2[0]][p2[1]] = temp
  new_keyboard
end

def iterate(keyboard)
  best = keyboard
  keyPos = [0, -1]
  for keyIndex in 0..25 do
    keyPos = incPos(keyPos, keyboard)
    switchPos = [0, -1]
    for switchIndex in 0..25 do
      switchPos = incPos(switchPos, keyboard)
      next if keyIndex == switchIndex
      newk = swapped(keyboard, keyPos, switchPos)
      best = total_badness_frequency(best) < total_badness_frequency(newk) ?
        best : newk
    end
  end
  best
end

def rating(keyboard)
  total_badness_frequency(keyboard) / (1.0 * $total_keys)
end

puts badness_frequency(column)
puts rating(qwerty)
puts rating(qwerty_adjusted)
puts rating(colemak)
new = colemak
# 300.times do
# new = iterate(new)
# end
# puts new
# puts rating(new)
# puts swapped(qwerty,[0,0],[1,1])

# 4x4 example

p = Rglpk::Problem.new
p.name = 'Keyboard'
p.obj.dir = Rglpk::GLP_MIN

matrix = []

numKeyCols = 2
keyPerCol = 2
keys = %w(a b c d)
numKeys = keys.count

# P_{ic} is an indicator variable which is true if k_i appears in column i
# in the final solution
# P_index computes the index of one of the H indicator variables
P_index = MIP.P_generator(numKeys,numKeyCols)
offset = P_index.range[1]+1

# H_{ijc} is an indicator variable which is true if k_i, and k_j are both
# in column c in the final solution
# H_index computes the index of one of the H indicator variables
H_index = MIP.H_generator(numKeys,numKeyCols,offset)
offset = H_index.range[1]+1

# M_{ik} is an indicator variable which is true if k_i, and k_j are in the
# same column in the final solution
# M_index computes the index of one of the M indicator variables
M_index = MIP.M_generator(numKeys,offset)
offset = M_index.range[1] +1

numVars = P_index.count + H_index.count + M_index.count

mipCols = p.add_cols(numVars)
mipCols.each do |col|
  col.set_bounds(Rglpk::GLP_DB, 0, 1)
  col.kind = Rglpk::GLP_IV
end

# result should be 8 with 4 keys in 2 cols of 2
objCoefs = [0] * numVars

testFrequency = {'a'=> {'b' => 400, 'd' => 4000}, 'b'=> {}, 'c'=> {'d'=> 300, 'a'=> 100}, 'd'=> {}}
C = ->(i,j) { 
  testFrequency[keys[i]][keys[j]].to_i + testFrequency[keys[j]][keys[i]].to_i 
}

# Minimize conflict given by Sum_{ij} M_{ij}C_{ij} where 
# C_{ij} gives the conflict rating of keys k_i and k_j
for i in 0..numKeys - 1 do
  for j in (i+1)..numKeys - 1 do
    objCoefs[M_index.call(i,j)] = C.call(i,j)
    puts [keys[i], keys[j], C.call(i,j), C.call(j,i)].inspect
  end
end
p.obj.coefs = objCoefs
puts objCoefs.inspect

# rules
# key must be in 1 column
for ki in 0..numKeys - 1 do
  row = [0] * numVars
  for ci in 0..numKeyCols - 1 do
    row[P_index.call(ki,ci)] = 1
  end
  lprows = p.add_rows(1)
  lprows[0].set_bounds(Rglpk::GLP_FX, 1, 1)
  matrix << row
end

# column must be filled
for ci in 0..numKeyCols - 1 do
  row = [0] * numVars
  for ki in 0..numKeys - 1 do
    row[P_index.call(ki,ci)] = 1
  end
  lprows = p.add_rows(1)
  lprows[0].set_bounds(Rglpk::GLP_FX, keyPerCol, keyPerCol)
  matrix << row
end

# key pair-column aggregator indacators are set
for k1 in 0..numKeys - 1 do
  for k2 in (k1 + 1)..numKeys - 1 do
    for col in 0..numKeyCols - 1 do
      t = H_index.call(k1, k2, col)
      v1 = P_index.call(k1,col)
      v2 = P_index.call(k2,col)
      MIP.and(p, matrix, t, v1, v2)
    end
  end
end

# compute M_{ij} as an or over H_{ijc}
for k1 in 0..numKeys - 1 do
  for k2 in (k1 + 1)..numKeys - 1 do
    t = M_index.call(k1, k2)
    vs = []
    for col in 0..numKeyCols - 1 do
      vs << H_index.call(k1,k2,col)
    end
    MIP.or(p, matrix, t, *vs)
  end
end

#puts matrix.to_a.map(&:inspect)
p.set_matrix(matrix.flatten)

p.simplex
p.mip(presolve: Rglpk::GLP_ON)
z = p.obj.mip
puts z

puts mipCols.map {|e| e.mip_val.to_i }.inspect
remaining_keys = keys.dup
board = []
for c in 0..numKeyCols-1 do
  col = []
  for k in 0..numKeys-1 do
    if mipCols[P_index.call(k,c)].mip_val == 1
      key = keys[k]
      col << key
      raise "key used twice" unless remaining_keys.delete key
    end
  end
  board << col
end
raise remaining_keys unless remaining_keys.empty?
puts board.to_a.map(&:inspect)
