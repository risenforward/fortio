#= require_tree ./models
#= require_self

$ ->
  window.pusher_subscriber = new PusherSubscriber()

Member.initData [window.current_user]
DepositChannel.initData window.deposit_channels
WithdrawChannel.initData window.withdraw_channels
Deposit.initData window.deposits
Account.initData window.accounts
Currency.initData window.currencies
Withdraw.initData window.withdraws
FundSource.initData window.fund_sources


window.app = app = angular.module 'funds', []


app.directive 'accounts', ->
  return {
    restrict: 'E'
    templateUrl: '/templates/accounts.html'
    controller: () ->
      this.accounts = Account.all()

    controllerAs: 'accountsCtrl'

  }
