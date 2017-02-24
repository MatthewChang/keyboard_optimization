class IndicatorSet
  def initialize(function,count,offset = 0)
    @funcion = function
    @count = count
    raise "Bad count" unless count > 0
    @offset = offset
  end

  def call(*args)
    @funcion.call(*args) + @offset
  end

  def count
    @count
  end

  def range
    [@offset, @offset + count - 1]
  end
end
