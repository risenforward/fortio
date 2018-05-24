# encoding: UTF-8
# frozen_string_literal: true

module Private
  class AssetsController < BaseController
    skip_before_action :auth_member!, only: [:index]

    def index
      Currency.enabled.each do |ccy|
        name = ccy.fiat? ? :fiat : ccy.code.to_sym
        instance_variable_set :"@#{name}_proof", Proof.current(ccy.code.to_sym)
        if current_user
          instance_variable_set :"@#{name}_account", \
            current_user.accounts.enabled.with_currency(ccy.code.to_sym).first
        end
      end
    end
  end
end
