/**
 * Main route controller
 */

var home = require('./home');

module.exports = function (app) {
    app.get('/', home.index);
};
