# People exchange commodities in markets. Each market focuses on certain
# commodity pair `{A, B}`. By convention, we call people exchange A for B
# *sellers* who submit *ask* orders, and people exchange B for A *buyers*
# who submit *bid* orders.
#
# ID of market is always in the form "#{B}#{A}". For example, in 'btccny'
# market, the commodity pair is `{btc, cny}`. Sellers sell out _btc_ for
# _cny_, buyers buy in _btc_ with _cny_. _btc_ is the `base_unit`, while
# _cny_ is the `quote_unit`.

class Market < ActiveYamlBase
  field :visible, default: true

  attr :name

  self.singleton_class.send :alias_method, :all_with_invisible, :all
  def self.all
    all_with_invisible.select &:visible
  end

  def self.enumerize
    all_with_invisible.inject({}) {|hash, i| hash[i.id.to_sym] = i.code; hash }
  end

  def initialize(*args)
    super

    raise "missing base_unit or quote_unit: #{args}" unless base_unit.present? && quote_unit.present?
    @name = "#{base_unit}/#{quote_unit}".upcase
  end

  def latest_price
    Trade.latest_price(id.to_sym)
  end

  # type is :ask or :bid
  def fix_number_precision(type, d)
    digits = send(type)['fixed']
    d.round digits, 2
  end

  def to_s
    id
  end

end
