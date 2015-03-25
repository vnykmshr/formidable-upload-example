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


Please note, `magickwand` is needed only if you're going to test `resize`. Follow
[Magickwand](https://github.com/qzaidi/magickwand) for instructions on installing it.

Pre-requisites (for magickwand)

On Linux: apt-get install libmagickwand-dev
On Mac (Using Homebrew) brew install imagemagick  --disable-openmp
