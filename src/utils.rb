
class String

  def valid_integer?
    true if Integer self rescue false
  end

  def valid_float?
    true if Float self rescue false
  end

end
