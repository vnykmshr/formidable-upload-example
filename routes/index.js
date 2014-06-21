/**
 * Main route controller
 */

var home = require('./home');
var upload = require('formidable-upload');

var uploader = upload()
    .accept(/image*/)
    .to(['public', 'data', 'images'], '9876543210')
    .resize({
        use: 'resize',
        settings: {
            width: 800,
            quality: 80
        }
    });
    .imguri();

module.exports = function (app) {
    app.get('/', home.index);
    app.get('/upload', home.index);
    app.post('/upload', uploader.middleware('imagefile'), home.upload, home.errors);
};
