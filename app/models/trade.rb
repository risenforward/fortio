# encoding: UTF-8
# frozen_string_literal: true

class Trade < ActiveRecord::Base
  include BelongsToMarket
  extend Enumerize
  ZERO = '0.0'.to_d

  enumerize :trend, in: { up: 1, down: 0 }

  belongs_to :ask, class_name: 'OrderAsk', foreign_key: :ask_id, required: true
  belongs_to :bid, class_name: 'OrderBid', foreign_key: :bid_id, required: true
  belongs_to :ask_member, class_name: 'Member', foreign_key: :ask_member_id, required: true
  belongs_to :bid_member, class_name: 'Member', foreign_key: :bid_member_id, required: true

  validates :price, :volume, :funds, numericality: { greater_than_or_equal_to: 0.to_d }

  scope :h24, -> { where('created_at > ?', 24.hours.ago) }

  attr_accessor :side

  after_commit on: :create do
    EventAPI.notify ['market', market_id, 'trade_completed'].join('.'), \
      Serializers::EventAPI::TradeCompleted.call(self)
  end

  class << self
    def latest_price(market)
      with_market(market).order(id: :desc).select(:price).first.try(:price) || 0.to_d
    end

    def filter(market, timestamp, from, to, limit, order)
      trades = with_market(market).order(order)
      trades = trades.limit(limit) if limit.present?
      trades = trades.where('created_at <= ?', timestamp) if timestamp.present?
      trades = trades.where('id > ?', from) if from.present?
      trades = trades.where('id < ?', to) if to.present?
      trades
    end

    def for_member(market, member, options={})
      trades = filter(market, options[:time_to], options[:from], options[:to], options[:limit], options[:order]).where("ask_member_id = ? or bid_member_id = ?", member.id, member.id)
      trades.each do |trade|
        trade.side = trade.ask_member_id == member.id ? 'ask' : 'bid'
      end
    end

    def avg_h24_price(market)
      with_market(market).h24.select(:price).average(:price).to_d
    end
  end

  def for_notify(kind = nil)
    { id:     id,
      kind:   kind || side,
      at:     created_at.to_i,
      price:  price.to_s  || ZERO,
      volume: volume.to_s || ZERO,
      ask_id: ask_id,
      bid_id: bid_id,
      market: market.id }
  end

  def for_global
    { tid:    id,
      type:   trend == 'down' ? 'sell' : 'buy',
      date:   created_at.to_i,
      price:  price.to_s || ZERO,
      amount: volume.to_s || ZERO }
  end

  def record_complete_operations!
    transaction do
      record_liability_debit!
      record_liability_credit!
      record_liability_transfer!
      record_revenues!
    end
  end

  private
  def record_liability_debit!
    ask_currency_outcome = volume
    bid_currency_outcome = funds

    # Debit locked fiat/crypto Liability account for member who created ask.
    Operations::Liability.debit!(
      reference: self,
      amount:    ask_currency_outcome,
      kind:      :locked,
      member_id: ask.member_id,
      currency:  ask.currency
    )
    # Debit locked fiat/crypto Liability account for member who created bid.
    Operations::Liability.debit!(
      reference: self,
      amount:    bid_currency_outcome,
      kind:      :locked,
      member_id: bid.member_id,
      currency:  bid.currency
    )
  end

  def record_liability_credit!
    # We multiply ask outcome by bid fee.
    # Fees are related to side bid or ask (not currency).
    ask_currency_income = volume - volume * bid.fee
    bid_currency_income = funds - funds * ask.fee

    # Credit main fiat/crypto Liability account for member who created ask.
    Operations::Liability.credit!(
      reference: self,
      amount:    bid_currency_income,
      kind:      :main,
      member_id: ask.member_id,
      currency:  bid.currency
    )

    # Credit main fiat/crypto Liability account for member who created bid.
    Operations::Liability.credit!(
      reference: self,
      amount:    ask_currency_income,
      kind:      :main,
      member_id: bid.member_id,
      currency:  ask.currency
    )
  end

  def record_liability_transfer!
    # Unlock unused funds.
    [bid, ask].each do |order|
      if order.volume.zero? && !order.locked.zero?
        Operations::Liability.transfer!(
          reference: self,
          amount:    order.locked,
          from_kind: :locked,
          to_kind:   :main,
          member_id: order.member_id,
          currency:  order.currency
        )
      end
    end
  end

  def record_revenues!
    ask_currency_fee = volume * bid.fee
    bid_currency_fee = funds * ask.fee

    # Credit main fiat/crypto Revenue account.
    Operations::Revenue.credit!(
      reference: self,
      amount:    ask_currency_fee,
      currency:  ask.currency
    )

    # Credit main fiat/crypto Revenue account.
    Operations::Revenue.credit!(
      reference: self,
      amount:    bid_currency_fee,
      currency:  bid.currency
    )
  end
end

# == Schema Information
# Schema version: 20180813105100
#
# Table name: trades
#
#  id            :integer          not null, primary key
#  price         :decimal(32, 16)  not null
#  volume        :decimal(32, 16)  not null
#  ask_id        :integer          not null
#  bid_id        :integer          not null
#  trend         :integer          not null
#  market_id     :string(20)       not null
#  ask_member_id :integer          not null
#  bid_member_id :integer          not null
#  funds         :decimal(32, 16)  not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_trades_on_ask_id                           (ask_id)
#  index_trades_on_ask_member_id_and_bid_member_id  (ask_member_id,bid_member_id)
#  index_trades_on_bid_id                           (bid_id)
#  index_trades_on_market_id_and_created_at         (market_id,created_at)
#
