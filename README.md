# Nostr HTML

## How to run

Store events with [nosdump-and-store](https://github.com/kaosf/nosdump-and-store) at first.

`stylesheet/style.css` is [here](https://github.com/kaosf/kaosfield/blob/20b7b84c5d22fce751fdc5cdbe4d5112ab5eacb7/static/stylesheets/style.css).

Modify `templates/*.html.erb` for yourself.

Refer the example `compose.yaml` to run it.

HTML and JSON contents will be stored into `data/www`.

## Development

```sh
vi .env
# Edit it for yourself.
# e.g.
cat <<'EOF' > .env
DATABASE_URL=postgres://user:pass@host:5432/db
EOF
chmod 600 .env

mkdir -p data/www
bundle
IS_DEVELOPMENT=1 TZ=Asia/Tokyo SLEEP_SECONDS=5 bundle exec ruby app.rb

cp -r data/www /path/to/www/document-root/
```

## License

[![Public Domain](http://i.creativecommons.org/p/mark/1.0/88x31.png)](http://creativecommons.org/publicdomain/mark/1.0/ "license")

This work is free of known copyright restrictions.
