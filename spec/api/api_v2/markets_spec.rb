# encoding: UTF-8
# frozen_string_literal: true

describe APIv2::Markets, type: :request do
  describe 'GET /api/v2/markets' do
    it 'lists enabled markets' do
      get '/api/v2/markets'
      expect(response).to be_success
      expect(response.body).to eq '[{"id":"btcusd","name":"BTC/USD"},{"id":"dashbtc","name":"DASH/BTC"}]'
    end
  end
end
