replaceWhitespace = (val)->
  val.replace /\s*/g, ""

@Billing =
  settings: {}

  config: (opts) ->
    @settings = _.extend @settings, opts

  isValid: ->
    $('form#billing-creditcard').parsley().validate()

  createBillingObject: (form) ->
    $form = $(form)

    billTo = {
      firstName: $(form).find('[name=cc-firstname]').val(),
      lastName: $(form).find('[name=cc-lastname]').val(),
      address: $form.find('[name=cc-address]').val(),
      city: $form.find('[name=cc-address-city]').val(),
      state: $form.find('[name=cc-address-state]').val(),
      zip: $form.find('[name=cc-address-zip]').val()
    }

    creditCard = {
      cardNumber: replaceWhitespace($form.find('[name=cc-num]').val()),
      expirationDate: replaceWhitespace($form.find('[name=cc-exp-year]').val()) + "-" + replaceWhitespace($form.find('[name=cc-exp-month]').val()),
      cardCode: replaceWhitespace($form.find('[name=cc-cvc]').val())
    }

    {billTo: billTo, creditCard: creditCard}