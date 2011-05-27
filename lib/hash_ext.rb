module HashExt
  # Return a new hash with all keys converted to strings.
  def stringify_keys
    dup.stringify_keys!
  end

  # Destructively convert all keys to strings.
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end

  # Return a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  def symbolize_keys
    dup.symbolize_keys!
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+.
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  def stringify_symbol_values!
    keys.each do |key|
      self[key] = self[key].to_s if self[key].is_a? Symbol
    end
    self
  end

  alias_method :to_options,  :symbolize_keys
  alias_method :to_options!, :symbolize_keys!

  def recursive_stringify_keys!
    stringify_keys!
    values.select{|v| v.is_a? Hash}.each{|h| h.recursive_stringify_keys!}
    self
  end

  def recursive_symbolize_keys!
    symbolize_keys!
    values.select{|v| v.is_a? Hash}.each{|h| h.recursive_symbolize_keys!}
    self
  end

  def recursive_stringify_symbol_values!
    stringify_symbol_values!
    values.select{|v| v.is_a? Hash}.each{|h| h.recursive_stringify_symbol_values!}
    self
  end
end

class Hash
  include HashExt
end