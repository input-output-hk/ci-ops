class Hash(K, V)
  def deep_merge(other : Hash(L, W)) forall L, W
    target = Hash(K | L, V | W).new
    target.merge! self

    other.keys.each do |key|
      # keys only in other
      if !self[key]?
        target[key] = other[key]
        next
      end

      # merge if both are hashes
      me = self[key]
      them = other[key]
      if me.is_a?(Hash) && them.is_a?(Hash)
        target[key] = me.deep_merge(them)
        next
      end

      # otherwise take from other
      target[key] = other[key]
    end

    target
  end

  def deep_merge!(other : Hash(L, W)) forall L, W
    other.keys.each do |key|
      # keys only in other
      if !self[key]?
        self[key] = other[key]
        next
      end

      # merge if both are hashes
      me = self[key]
      them = other[key]
      if me.is_a?(Hash) && them.is_a?(Hash)
        self[key] = me.deep_merge!(them)
        next
      end

      # otherwise take from other
      self[key] = other[key]
    end

    self
  end
end
