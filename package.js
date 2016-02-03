Package.describe({
  name: "billing",
  summary: "Various billing functionality packaged up.",
  version: "1.0.1"
});

Package.on_use(function (api, where) {
  api.versionsFrom("METEOR@1.2");

  api.use([
    'templating',
    'less',
    'jquery',
    'deps',
    'natestrauser:parsleyjs@1.1.7',
    'mrt:accounts-t9n'
  ], 'client');

  api.use([
    'accounts-password',
    'arunoda:npm@0.2.6'
  ], 'server');

  api.use([
    'coffeescript',
    'mrt:minimongoid@0.8.8'
  ], ['client', 'server']);

  Npm.depends({
    'auth-net-cim': '2.2.0',
    'auth-net-types': '1.1.0',
    'authorize-net-arb': '0.0.4'
  });

  api.addFiles([
    'collections/users.coffee'
  ], ['client', 'server']);

  api.addFiles([
    'client/views/creditCard/creditCard.html',
    'client/views/creditCard/creditCard.less',
    'client/views/creditCard/creditCard.coffee',
    'client/lib/parsley.css',
    'client/startup.coffee',
    'client/billing.coffee',
    'client/styles.less',
    'client/i18n/english.coffee'
  ], 'client');

  api.addFiles([
    'server/startup.coffee',
    'server/billing.coffee'
  ], 'server');

  api.export('BillingUser', ['server', 'client']);

});
