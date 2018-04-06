require_dependency 'admin/withdraws/base_controller'

module Admin
  module Withdraws
    class CoinsController < BaseController
      before_action :find_withdraw, only: [:show, :update, :destroy]

      def index
        @latest_withdraws  = ::Withdraws::Coin.where(currency: currency)
                                              .where('created_at <= ?', 1.day.ago)
                                              .order(id: :desc)
        @all_withdraws     = ::Withdraws::Coin.where(currency: currency)
                                              .where('created_at > ?', 1.day.ago)
                                              .order(id: :desc)
      end

      def show

      end

      def update
        @withdraw.transaction do
          @withdraw.accept!
          @withdraw.process!
        end
        redirect_to :back, notice: t('admin.withdraws.coins.update.notice')
      end

      def destroy
        @withdraw.reject!
        redirect_to :back, notice: t('admin.withdraws.coins.update.notice')
      end
    end
  end
end
