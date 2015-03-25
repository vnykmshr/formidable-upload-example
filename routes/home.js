/**
 * Home controller
 */

var home = {
    index: function index(req, res, next) {
        res.locals.title = 'Home';
        res.render('index');
    },

    upload: function uploadfn(req, res, next) {
        res.json(req.files);
    },

    errors: function errorsfn(err, req, res, next) {
        res.json({
            result: 'failed',
            error: err.message
        });
    }
};

module.exports = home;
