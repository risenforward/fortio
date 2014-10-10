Peatio.WithdrawsController = Ember.ArrayController.extend
  init: ->
    controller = @
    @._super()

    $.subscribe 'account:update', (event, data) ->
      $("#withdraw_balance").html(controller.model[0].account().balance)

    $.subscribe 'withdraw:create', ->
      record = controller.get('model')[0].account().withdraws().pop()
      controller.get('withdraws').insertAt(0, record)

      if controller.get('withdraws').length > 3
        setTimeout(->
          controller.get('withdraws').popObject()
        , 1000)


      setTimeout( ->
        $('.cancel_link:first').bind('click', (event)->
          event.preventDefault()
          event.stopPropagation()
          record_id = event.target.dataset.id
          controller.cancelDepositAction(record_id, event.target)
        )
      , 500)


    setTimeout( ->
    # Thanks to ember that, we can't handle this click by ember's action
    # It won't support firefox to get the event after clicking the link.
    # Fck Ember
      $('.cancel_link').on('click', (event)->
        event.preventDefault()
        event.stopPropagation()
        record_id = event.target.dataset.id
        controller.cancelDepositAction(record_id, event.target)
      )
    , 100)


  btc: (->
    @model[0].currency == "btc"
  ).property('@each')

  cny: (->
    @model[0].currency == "cny"
  ).property('@each')

  withdraws: (->
    @model[0].account().topWithdraws()
  ).property('@each')

  balance: (->
    @model[0].account().balance
  ).property('@each')

  fsources: (->
    FundSource.findAllBy('currency', @model[0].currency)
  ).property('@each')

  name: (->
    current_user.name
  ).property('')

  app_activated: (->
    current_user.app_activated
  ).property('')

  sms_activated: (->
    current_user.sms_activated
  ).property('')

  app_and_sms_activated: (->
    current_user.app_activated and current_user.sms_activated
  ).property('')

  cancelDepositAction: (record_id, target) ->
    url = "/withdraws/#{@model[0].resources_name}/#{record_id}"
    $.ajax({
      url: url
      method: 'DELETE'
    }).done(->
      $(target).remove()
    )



  actions: {
    withdrawAll: ->
      $('#withdraw_sum').val(@get('balance'))

    submitWithdraw: ->
      fund_source = $('#fund_source').val()
      sum = $('#withdraw_sum').val()
      currency = @model[0].currency
      account = @model[0].account()
      data = { withdraw: { account_id: account.id, member_id: current_user.id, currency: currency, sum: sum,  fund_source: fund_source }}

      if current_user.app_activated or current_user.sms_activated
        type = $('.two_factor_auth_type').val()
        otp = $("#two_factor_otp").val()
        data['two_factor'] = { type: type, otp: otp }

      $('#withdraw_submit').attr('disabled', 'disabled')
      $.ajax({
        url: "/withdraws/#{@model[0].resources_name}",
        method: 'post',
        data: data
      }).always(->
        $('#withdraw_submit').removeAttr('disabled')
      ).fail((result)->
        $.publish 'flash', {message: result.responseText }
      ).done(->
        $('#withdraw_sum').val('')
      )

  }

