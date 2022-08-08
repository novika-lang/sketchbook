# :nodoc:
module BaseStream
end

class Stream(T)
  include BaseStream

  @listeners = Set(BaseStream).new

  # Subscribes *listener* to events in this stream.
  def sub(listener : BaseStream) : BaseStream
    listener.tap { @listeners << listener }
  end

  # Un-subscribes *listener* from events in this stream.
  def unsub(listener : BaseStream)
    @listeners.delete(listener)
  end

  # Pumps *object* to listening streams.
  def pump(object : T)
    @listeners.each &.pump(self, object)
  end

  # :ditto:
  def pump(sender, object : T)
    pump(object)
  end

  # :ditto:
  def pump(sender, object) : NoReturn
    raise "#{self} expected #{T}, but was given: #{object.class}"
  end

  # Calls *func* before pumping an object unchanged.
  def each(&func : T ->)
    sub Each(T).new(func)
  end

  # Pumps an object transformed by *func*.
  def map(&func : T -> U) forall U
    sub Map(T, U).new(func)
  end

  # Pumps only those objects for which *func* returns true.
  def when(&func : T -> Bool)
    sub Select(T).new(func)
  end

  # Pumps only those objects that are of the given *type*.
  def when(type : U.class) forall U
    self.when { |object| object.is_a?(U) }.map &.as(U)
  end

  # Pumps only those objects that match against *pattern*
  # (using `===`).
  def when(pattern)
    self.when { |object| pattern === object }
  end

  # Pumps only those objects for which *func* returns false.
  def except(&func : T -> Bool)
    self.when { |object| !func.call(object) }
  end

  # Pumps only those objects that **do not** match against
  # *pattern* (using `===`).
  def except(pattern)
    self.when { |object| !(pattern === object) }
  end

  # Pumps only if the result of *func* over the pumped object
  # is not equal (`==`) to its previous result.
  #
  # The first pumped object is always pumped.
  def uniq(&func : T -> U) forall U
    sub Uniq(T, U).new(func)
  end

  # Pumps only if the pumped object is not equal to the
  # previous pumped object.
  def uniq
    uniq { |it| it }
  end

  # Pumps objects from this stream to the returned stream
  # when *a* receives an object, and stops pumping when
  # *b* receives a value.
  def all(between a : Stream(M), and b : Stream(K), now = false) forall M, K
    Stream(T).new.tap do |output|
      sub output if now
      a.each { sub output }
      b.each { unsub output }
    end
  end
end

private class Each(T) < Stream(T)
  def initialize(@func : T ->)
  end

  def pump(object : T)
    @func.call(object)
    super
  end
end

private class Select(T) < Stream(T)
  def initialize(@sel : T -> Bool)
  end

  def pump(sender, object : T)
    super if @sel.call(object)
  end
end

private class Uniq(T, U) < Stream(T)
  @memo : U?

  def initialize(@func : T -> U)
  end

  def pump(sender, object : T)
    value = @func.call(object)
    @memo, prev = value, @memo
    return super unless prev == value
  end
end

private class Map(T, U) < Stream(U)
  def initialize(@func : T -> U)
  end

  def pump(sender, object : T)
    super @func.call(object)
  end
end
