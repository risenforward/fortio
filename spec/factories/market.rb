# encoding: UTF-8
# frozen_string_literal: true

FactoryBot.define do
  factory :market do
    trait :btcusd do
      id            'btcusd'
      ask_unit      'btc'
      bid_unit      'usd'
      ask_fee       0.0015
      bid_fee       0.0015
      ask_precision 4
      bid_precision 4
      position      1
      enabled       true
    end

    trait :dashbtc do
      id            'dashbtc'
      ask_unit      'dash'
      bid_unit      'btc'
      ask_fee       0.0015
      bid_fee       0.0015
      ask_precision 4
      bid_precision 4
      position      2
      enabled       true
    end
  end
end
