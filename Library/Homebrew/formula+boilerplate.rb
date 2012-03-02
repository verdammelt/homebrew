
class Formula

  def inspect
    name
  end

  def == b
    name == b.name
  end

  def eql? b
    self == b and self.class.equal? b.class
  end

  def hash
    name.hash
  end

  def <=> b
    name <=> b.name
  end

  def to_s
    name
  end

  def method_added method
    raise 'You cannot override Formula.brew' if method == 'brew'
  end

end
