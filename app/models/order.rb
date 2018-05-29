# encoding: UTF-8
# frozen_string_literal: true

class Order < ActiveRecord::Base
  include BelongsToMarket
  include BelongsToMember

  extend Enumerize
  enumerize :state, in: { wait: 100, done: 200, cancel: 0 }, scope: true

  TYPES = %w[ market limit ]
  enumerize :ord_type, in: TYPES, scope: true

  after_commit(on: :create) { trigger_pusher_event }
  before_validation :fix_number_precision, on: :create

  validates :ord_type, :volume, :origin_volume, :locked, :origin_locked, presence: true
  validates :origin_volume, numericality: { greater_than: 0.to_d }
  validates :price, numericality: { greater_than: 0, allow_nil: false }, if: -> (order) { order.ord_type == 'limit' }
  validate  :market_order_validations, if: -> (order) { order.ord_type == 'market' }

  WAIT   = 'wait'
  DONE   = 'done'
  CANCEL = 'cancel'

  scope :done, -> { with_state(:done) }
  scope :active, -> { with_state(:wait) }

  before_validation(on: :create) { self.fee = config.public_send("#{kind}_fee") }

  after_commit on: :create do
    next unless ord_type == 'limit'
    EventAPI.notify ['market', market_id, 'order_created'].join('.'), \
      Serializers::EventAPI::OrderCreated.call(self)
  end

  after_commit on: :update do
    next unless ord_type == 'limit'
    event = case previous_changes.dig('state', 1)
      when 'cancel' then 'order_canceled'
      when 'done'   then 'order_completed'
      else 'order_updated'
    end

    EventAPI.notify ['market', market_id, event].join('.'), \
      Serializers::EventAPI.const_get(event.camelize).call(self)
  end

  def funds_used
    origin_locked - locked
  end

  def config
    @config ||= Market.find(market_id)
  end

  def trigger_pusher_event
    Member.trigger_pusher_event member_id, :order, \
      id:            id,
      at:            at,
      market:        market_id,
      kind:          kind,
      price:         price&.to_s('F'),
      state:         state,
      volume:        volume.to_s('F'),
      origin_volume: origin_volume.to_s('F')
  end

  def strike(trade)
    raise "Cannot strike on canceled or done order. id: #{id}, state: #{state}" unless state == Order::WAIT

    real_sub, add  = get_account_changes(trade)
    real_fee       = add * fee
    real_add       = add - real_fee
    hold_account   = hold_account!
    expect_account = expect_account!

    hold_account.unlock_and_sub_funds!(real_sub)
    expect_account.plus_funds!(real_add)

    self.volume         -= trade.volume
    self.locked         -= real_sub
    self.funds_received += add
    self.trades_count   += 1

    if volume.zero?
      self.state = Order::DONE

      # unlock not used funds
      hold_account.unlock_funds!(locked) unless locked.zero?
    elsif ord_type == 'market' && locked.zero?
      # partially filled market order has run out its locked fund
      self.state = Order::CANCEL
    end

    save!
  end

  def kind
    self.class.name.underscore[-3, 3]
  end

  def at
    created_at.to_i
  end

  def self.head(currency)
    active.with_market(currency).matching_rule.first
  end

  def to_matching_attributes
    { id:        id,
      market:    market_id,
      type:      type[-3, 3].downcase.to_sym,
      ord_type:  ord_type,
      volume:    volume,
      price:     price,
      locked:    locked,
      timestamp: created_at.to_i }
  end

  def fix_number_precision
    self.price = config.fix_number_precision(:bid, price.to_d) if price

    if volume
      self.volume = config.fix_number_precision(:ask, volume.to_d)
      self.origin_volume = origin_volume.present? ? config.fix_number_precision(:ask, origin_volume.to_d) : volume
    end
  end

  private

  def market_order_validations
    errors.add(:price, 'must not be present') if price.present?
  end

  FUSE = '0.9'.to_d
  def estimate_required_funds(price_levels)
    required_funds = Account::ZERO
    expected_volume = volume

    start_from, _ = price_levels.first
    filled_at     = start_from

    until expected_volume.zero? || price_levels.empty?
      level_price, level_volume = price_levels.shift
      filled_at = level_price

      v = [expected_volume, level_volume].min
      required_funds += yield level_price, v
      expected_volume -= v
    end

    raise "Market is not deep enough" unless expected_volume.zero?
    raise "Volume too large" if (filled_at-start_from).abs/start_from > FUSE

    required_funds
  end

end

# == Schema Information
# Schema version: 20180516133138
#
# Table name: orders
#
#  id             :integer          not null, primary key
#  bid            :integer          not null
#  ask            :integer          not null
#  market_id      :string(10)       not null
#  price          :decimal(32, 16)
#  volume         :decimal(32, 16)  not null
#  origin_volume  :decimal(32, 16)  not null
#  fee            :decimal(32, 16)  default(0.0), not null
#  state          :integer          not null
#  type           :string(8)        not null
#  member_id      :integer          not null
#  ord_type       :string           not null
#  locked         :decimal(32, 16)  default(0.0), not null
#  origin_locked  :decimal(32, 16)  default(0.0), not null
#  funds_received :decimal(32, 16)  default(0.0)
#  trades_count   :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_orders_on_member_id                     (member_id)
#  index_orders_on_state                         (state)
#  index_orders_on_type_and_market_id            (type,market_id)
#  index_orders_on_type_and_member_id            (type,member_id)
#  index_orders_on_type_and_state_and_market_id  (type,state,market_id)
#  index_orders_on_type_and_state_and_member_id  (type,state,member_id)
#
