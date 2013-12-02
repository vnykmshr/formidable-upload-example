var util = require('util');
var http = require('http');
var path = require('path');
var express = require('express');

var config = require('./config');

var app = express();

// all environments
app.set('port', config.port || process.env.PORT || 3000);
app.set('views', path.join(__dirname, 'views'));
require('./lib/view')(app);
app.use(express.favicon());
app.use(express.logger('dev'));
app.use(express.compress());
app.use(express.json());
app.use(express.urlencoded());
app.use(express.methodOverride());
app.use(app.router);
app.use(express.static(path.join(__dirname, 'public')));

// development only
if ('development' === app.get('env')) {
  app.use(express.errorHandler());
}

require('./routes')(app);

http.createServer(app)
  .on('error', function (err) {
    console.log(err);
    process.exit(1);
  })
  .listen(app.get('port'), function () {
    util.log("Web server listening on port " + app.get('port') + ' in ' + app.get('env'));
  });
