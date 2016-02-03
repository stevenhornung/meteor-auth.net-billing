billingErrorMessages = {
  'E00003': 'Invalid payment input. Please check that all values you entered are correct.'
}

AuthTypes = Npm.require('auth-net-types')
_AuthorizeCIM = Npm.require('auth-net-cim')
AuthorizeCIM = null
_ARB = Npm.require('authorize-net-arb')
ARB = null
Future = Npm.require("fibers/future")

Meteor.startup ->
  AuthorizeCIM = new _AuthorizeCIM({
    api: Billing.settings.api,
    key: Billing.settings.key,
    sandbox: Billing.settings.sandbox
  })

  if Billing.settings.sandbox
    _ARB.useSandbox()
  ARB = _ARB.client(Billing.settings.api, Billing.settings.key)

validatePayment = (user, customerProfileId, customerPaymentProfileId) ->
  # Validate payment profile
  validateOptions = {
    customerProfileId: customerProfileId,
    customerPaymentProfileId: customerPaymentProfileId,
    validationMode: if Billing.settings.sandbox then 'testMode' else 'liveMode'
  }
  validateCustomerPaymentProfile = Async.wrap AuthorizeCIM, 'validateCustomerPaymentProfile'
  try
    validateCustomerPaymentProfile validateOptions
  catch e
    deletePayment(user, customerProfileId, customerPaymentProfileId)
    throw new Meteor.Error 500, Billing.errorMessage(e)

deletePayment = (user, customerProfileId, customerPaymentProfileId) ->
  deleteCustomerPaymentProfile = Async.wrap AuthorizeCIM, 'deleteCustomerPaymentProfile'
  try
    deleteCustomerPaymentProfile {customerProfileId: customerProfileId, customerPaymentProfileId: customerPaymentProfileId}
    user.update 'billing.customerPaymentProfileId': null
  catch e
    throw new Meteor.Error 500, Billing.errorMessage(e)

updateUserCustomerProfile = (user, message) ->
  regex = new RegExp("^Authorize.net error: A duplicate record with ID ([0-9]+) already exists.$")
  match = message.match(regex)
  if match
    customerProfileId = match[1]
    user.update 'billing.customerProfileId': customerProfileId
    getCustomerProfile = Async.wrap AuthorizeCIM, 'getCustomerProfile'
    try
      customerProfile = getCustomerProfile customerProfileId
      customerPaymentProfileId = customerProfile.profile.paymentProfiles.customerPaymentProfileId
      user.update 'billing.customerPaymentProfileId': customerPaymentProfileId
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)

@Billing =
  settings: {}

  config: (opts) ->
    defaults =
      api: ''
      key: ''
      sandbox: true
    @settings = _.extend defaults, opts

  errorMessage: (err) ->
    message = billingErrorMessages[err.code]
    if message
      message
    else
      err.message.replace(/^Authorize.net error: /, '')

  isDuplicateRecord: (code) ->
    code is 'E00039'

  createCustomerAndCard: (billing) ->
    userId = Meteor.userId()
    unless userId
      throw new Meteor.Error 403, "You must be signed in to perform this action."

    user = BillingUser.first {_id: userId},
      fields:
        emails: 1

    unless user
      throw new Meteor.Error 404, "User not found.  Customer cannot be created."

    console.log 'Creating customer for', userId

    profile = {
      email: if user.emails then user.emails[0].address else ''
    }

    profile.paymentProfiles = new AuthTypes.PaymentProfiles({
      customerType: 'individual',
      billTo: new AuthTypes.BillingAddress(billing.billTo),
      payment: {
        creditCard: new AuthTypes.CreditCard(billing.creditCard)
      }
    })

    createCustomerProfile = Async.wrap AuthorizeCIM, 'createCustomerProfile'
    try
      customer = createCustomerProfile {customerProfile: profile}
      user.update 'billing.customerProfileId': customer.customerProfileId
      customerPaymentProfileId = customer.customerPaymentProfileIdList.numericString
      validatePayment(user, customer.customerProfileId, customerPaymentProfileId)
      user.update 'billing.customerPaymentProfileId': customerPaymentProfileId
    catch e
      # Update our user if they already have a customer profile
      if Billing.isDuplicateRecord(e.code)
        updateUserCustomerProfile(user, e.message)
      else
        console.error e
        throw new Meteor.Error 500, Billing.errorMessage(e)

  createCard: (billing) ->
    userId = Meteor.userId()
    unless userId
      throw new Meteor.Error 403, "You must be signed in to perform this action."


    user = BillingUser.first {_id: userId},
      fields:
        billing: 1

    unless user
      throw new Meteor.Error 404, "User not found. Card cannot be created."

    console.log 'Creating card for', userId

    paymentProfile = {
      customerType: 'individual',
      billTo: new AuthTypes.BillingAddress(billing.billTo),
      payment: {
        creditCard: new AuthTypes.CreditCard(billing.creditCard)
      }
    }

    createCustomerPaymentProfile = Async.wrap AuthorizeCIM, 'createCustomerPaymentProfile'
    try
      customer = createCustomerPaymentProfile {customerProfileId: user.billing.customerProfileId, paymentProfile: paymentProfile}
      validatePayment(user, user.billing.customerProfileId, customer.customerPaymentProfileId)
      user.update 'billing.customerPaymentProfileId': customer.customerPaymentProfileId
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)

  createCharge: (description, amount) ->
    userId = Meteor.userId()
    unless userId
      throw new Meteor.Error 403, "You must be signed in to perform this action."

    user = BillingUser.first {_id: userId},
      fields:
        billing: 1

    unless user
      throw new Meteor.Error 404, "User not found. Charge cannot be created."

    console.log "Creating charge"

    params = {
      customerProfileId: user.billing.customerProfileId,
      customerPaymentProfileId: user.billing.customerPaymentProfileId,
      amount: amount,
      order: {
        description: description
      }
    }

    createCustomerProfileTransaction = Async.wrap AuthorizeCIM, 'createCustomerProfileTransaction'
    try
      createCustomerProfileTransaction 'AuthCapture', params
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)

  createSubscription: (params, billing) ->
    userId = Meteor.userId()
    unless userId
      throw new Meteor.Error 403, "You must be signed in to perform this action."

    console.log "Creating subscription"

    request = {
      refId: userId,
      subscription: {
        name: params.name,
        order: {
          description: params.description
        },
        paymentSchedule: {
          interval: {
            length: 1,
            unit: 'months'
          },
          startDate: moment().tz("America/New_York").startOf('day').format('YYYY-MM-DD'),
          totalOccurrences: 12
        },
        amount: params.amount,
        billTo: billing.billTo,
        payment: {
          creditCard: billing.creditCard
        }
      }
    }

    future = new Future()
    ARB.createSubscription request, (err, res) ->
      if err
        future.throw err
      else
        future.return res

    try
      return future.wait()
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)

  cancelSubscription: (subscriptionId, userId) ->
    if userId isnt Meteor.userId()
      unless Roles.userIsInRole(Meteor.userId(), ['admin'])
        throw new Meteor.Error 403, "You are not aloud to perform this action."

    unless userId
      throw new Meteor.Error 403, "You must be signed in to perform this action."

    console.log "Cancel subscription"

    request = {
      refId: userId,
      subscriptionId: subscriptionId
    }

    future = new Future()
    ARB.cancelSubscription request, (err, res) ->
      if err
        future.throw err
      else
        future.return res

    try
      return future.wait()
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)

  updateSubscription: (params) ->
    userId = Meteor.userId()
    unless userId
      throw new Meteor.Error 403, "You must be signed in to perform this action."

    console.log "Update subscription"

    request = {
      refId: userId,
      subscriptionId: params.subscriptionId,
      subscription: {
        name: params.name,
        order: {
          description: params.description
        },
        amount: params.amount
      }
    }

    if params.billing
      _.extend request.subscription, {
        billTo: params.billing.billTo,
        payment: {
          creditCard: params.billing.creditCard
        }
      }

    future = new Future()
    ARB.updateSubscription request, (err, res) ->
      if err
        future.throw err
      else
        future.return res

    try
      return future.wait()
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)

Meteor.methods
  retrieveCard: ->
    unless Meteor.userId()
      throw new Meteor.Error 403, "You must be signed in to perform this action."

    console.log "Retrieving card for #{Meteor.userId()}"
    user = BillingUser.first {_id: Meteor.userId()},
      fields:
        billing: 1

    unless user
      throw new Meteor.Error 404, "User not found.  Cannot retrieve card info."

    getCustomerPaymentProfile = Async.wrap AuthorizeCIM, 'getCustomerPaymentProfile'
    try
      customerPaymentProfile = getCustomerPaymentProfile {customerProfileId: user.billing.customerProfileId, customerPaymentProfileId: user.billing.customerPaymentProfileId}
      customerPaymentProfile.paymentProfile.payment.creditCard
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)

  deleteCard: ->
    userId = Meteor.userId()
    unless userId
      throw new Meteor.Error 403, "You must be signed in to perform this action."

    user = BillingUser.first {_id: userId},
      fields:
        billing: 1

    unless user
      throw new Meteor.Error 404, "User not found.  Card cannot be deleted."

    console.log 'Deleting card for', userId

    try
      deletePayment(user, user.billing.customerProfileId, user.billing.customerPaymentProfileId)
    catch e
      console.error e
      throw new Meteor.Error 500, Billing.errorMessage(e)