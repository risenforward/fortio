# encoding: UTF-8
# frozen_string_literal: true

module Worker
  class DepositCollection
    def process(payload)
      Rails.logger.info { "Received request for deposit collection id: #{payload['id']}." }
      deposit = Deposit.find_by_id(payload['id'])

      unless deposit
        Rails.logger.warn { "The deposit with id: #{payload['id']} doesn't exist."}
        return
      end

      deposit.with_lock do
        if deposit.collected?
          Rails.logger.warn { "The deposit is now being processed by different worker or has been already processed. Skipping..." }
          return
        end
        wallet = Wallet.active.deposit.find_by(currency_id: deposit.currency_id)

        unless wallet
          Rails.logger.warn { "Can't find active deposit wallet for currency with code: #{deposit.currency_id}."}
          return
        end

        txid = WalletService[wallet].collect_deposit!(deposit)

        Rails.logger.warn { "The API accepted deposit collection and assigned transaction ID: #{txid}." }

        deposit.dispatch
        deposit.save!
      rescue => e
        report_exception(e)
        raise e
      end
    end
  end
end
