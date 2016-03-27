Package.describe({
  name: "billing",
  summary: "Common billing functionality using Authorize.net Payment Gateway.",
  version: "1.0.1"
});

Package.on_use(function (api, where) {
  api.versionsFrom("METEOR@1.2");

  api.use([
    'templating',
    'less',
    'jquery',
    'deps',
    'natestrauser:parsleyjs@1.1.7'
  ], 'client');

  api.use([
    'accounts-password',
    'arunoda:npm@0.2.6'
  ], 'server');

  api.use([
    'coffeescript'
  ], ['client', 'server']);

  Npm.depends({
    'auth-net-cim': '2.2.0',
    'auth-net-types': '1.1.0',
    'authorize-net-arb': '0.0.4'
  });

  api.addFiles([
    'client/views/creditCard/creditCard.html',
    'client/views/creditCard/creditCard.less',
    'client/lib/parsley.css',
    'client/startup.coffee',
    'client/billing.coffee',
    'client/styles.less',
  ], 'client');

  api.addFiles([
    'server/startup.coffee',
    'server/billing.coffee'
  ], 'server');
});
