require 'CSV'
require 'byebug'

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
300.times do
  new = iterate(new)
end
puts new
puts rating(new)
# puts swapped(qwerty,[0,0],[1,1])
