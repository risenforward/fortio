app.controller 'WithdrawsController', ['$scope', '$stateParams', '$http', '$gon', ($scope, $stateParams, $http, $gon) ->

  $scope.currency = currency = $stateParams.currency
  $scope.currencyTranslationLocals = currency: currency.toUpperCase()
  $scope.current_user = current_user = $gon.user
  $scope.account = Account.findBy('currency', $scope.currency)
  $scope.balance = $scope.account.balance
  $scope.withdraw_channel = WithdrawChannel.findBy('currency', $scope.currency)
  $scope.fiatCurrency = gon.fiat_currency
  $scope.fiatCurrencyTranslationLocals = currency: gon.fiat_currency.toUpperCase()

  @withdraw = {}
  @createWithdraw = (currency) ->
    data =
      withdraw:
        member_id: current_user.id
        currency:  currency
        sum:       @withdraw.sum
        rid:       @withdraw.rid

    $('.form-submit > input').attr('disabled', 'disabled')

    $http.post("/withdraws/#{currency}", data)
      .error (responseText) ->
        $.publish 'flash', { message: responseText }
      .finally =>
        @withdraw = {}
        $('.form-submit > input').removeAttr('disabled')
        $.publish 'withdraw:form:submitted'

  @withdrawAll = ->
    @withdraw.sum = Number($scope.account.balance)
]
