server {
  server_name myapp.com;
  root /var/www/myapp/releases/current/public/;
  index index.html index.htm;

  access_log /var/log/nginx/myapp.access.log;
  error_log  /var/log/nginx/myapp.error.log;
  underscores_in_headers on;

  recursive_error_pages on;
  error_page 503 @maintenance;

  if (-f $document_root/system/maintenance.html) {
    return 503;
  }

  location @maintenance {
    error_page 405 = /system/maintenance.html;
    rewrite  ^(.*)$  /system/maintenance.html break;
  }

  location ~ ^/(js|css|images|media|system)/ {
    autoindex off;
    add_header Cache-Control public;
    expires 4w;
  }

  location / {
    try_files $uri $uri/index.html @proxy;
  }

  location @proxy {
    proxy_pass   http://127.0.0.1:4120;
  }
}
