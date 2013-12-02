/**
 * Home controller
 */

var home = {
  index: function index(req, res, next) {
    res.locals.title = 'Home';
    res.render('index');
  }
};

module.exports = home;
