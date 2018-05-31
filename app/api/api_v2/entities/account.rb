# encoding: UTF-8
# frozen_string_literal: true

module APIv2
  module Entities
    class Account < Base
      expose :currency_id, as: :currency
      expose :balance, format_with: :decimal
      expose :locked,  format_with: :decimal
    end
  end
end
