formidable-upload-example
=========================

Example express app using formidable-upload

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

    // ..

    app.post('/upload', uploader.middleware('imagefile'), home.upload, home.errors);
