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
p.obj.dir = Rglpk::GLP_MAX

matrix = []

# rules
# each key must appear somewhere
# 4.times do
# rows = p.add_rows(1)
# matrix << [1,1,0,0]
# rows[0].name =""
# rows[0].set_bounds(Rglpk::GLP_UP,1,1)
# end

# rows = p.add_rows(3)
# rows[0].name = "p"
# rows[0].set_bounds(Rglpk::GLP_UP, 0, 100)
# rows[1].name = "q"
# rows[1].set_bounds(Rglpk::GLP_UP, 0, 600)
# rows[2].name = "r"
# rows[2].set_bounds(Rglpk::GLP_FX, 300, 300)

numKeyCols = 2
keyPerCol = 2
keys = %w(a b c d)
numKeys = keys.count
$numKeys = numKeys
numKeyColumnPairs = numKeys * (numKeys - 1) * numKeyCols / 2
numVars = (numKeyCols * numKeys) + numKeyColumnPairs
def keyPairCount(num)
  num * (num - 1) / 2
end

def keyColIndex(colIndex, keyIndex)
  colIndex * $numKeys + keyIndex
end

def keyPairIndex(keyIndex1, keyIndex2)
  (0..$numKeys).to_a.combination(2).to_a.index([keyIndex1, keyIndex2])
end

columnPairIndex = MIP.H_generator(numKeys,numKeyCols,numKeys*numKeyCols)

mipCols = p.add_cols(numVars)
mipCols.each do |col|
  col.set_bounds(Rglpk::GLP_DB, 0, 1)
  col.kind = Rglpk::GLP_IV
end

# A_{kc} is 1 if key k is in column c
# cols firs then keys

p.obj.coefs = [1] * numVars
# rules
# key must be in 1 column
for i in 0..numKeys - 1 do
  row = [0] * numVars
  for ci in 0..numKeyCols - 1 do
    row[keyColIndex(ci, i)] = 1
  end
  lprows = p.add_rows(1)
  lprows[0].set_bounds(Rglpk::GLP_FX, 1, 1)
  matrix << row
end

# column must be filled
for i in 0..numKeyCols - 1 do
  row = [0] * numVars
  for k in 0..numKeys - 1 do
    row[keyColIndex(i, k)] = 1
  end
  lprows = p.add_rows(1)
  lprows[0].set_bounds(Rglpk::GLP_FX, keyPerCol, keyPerCol)
  matrix << row
end

# key pair-column aggregator indacators are set
puts numVars
for k1 in 0..numKeys - 1 do
  for k2 in (k1 + 1)..numKeys - 1 do
    for col in 0..numKeyCols - 1 do
      t = columnPairIndex.call(k1, k2, col)
      puts t
      v1 = keyColIndex(col,k1)
      v2 = keyColIndex(col,k2)
      MIP.and(p, matrix, t, v1, v2)
    end
  end
end

puts matrix.to_a.map(&:inspect)
p.set_matrix(matrix.flatten)

p.simplex
p.mip(presolve: Rglpk::GLP_ON)
z = p.obj.mip
puts z
# for colNum in 0..numKeyCols-1 do
# col = []
# for ki in 0..numKeys-1 do
# col << keys[ki] if cos
# end
# end

# p.set_matrix([
# 1, 1, 1,
# 10, 4, 5,
# 2, 2, 6
# ])

# p.simplex
# p.mip
# z = p.obj.mip
# x1 = cols[0].mip_val
# x2 = cols[1].mip_val
# x3 = cols[2].mip_val

# printf("z = %g; x1 = %g; x2 = %g; x3 = %g\n", z, x1, x2, x3)
