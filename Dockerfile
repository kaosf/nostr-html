FROM ruby:4.0.5-alpine AS bundle
RUN apk --update-cache --no-cache add build-base imagemagick-dev
COPY ["Gemfile", "Gemfile.lock", "/"]
RUN bundle config set without development && bundle install

FROM ruby:4.0.5-alpine
COPY --from=bundle ["/usr/local/bundle", "/usr/local/bundle"]
RUN apk --update-cache --no-cache add libstdc++ imagemagick imagemagick-jpeg imagemagick-webp
COPY ["setup.sql", "/"]
COPY ["app.rb", "/nostr-html.rb"]
COPY ["templates", "/templates"]
CMD ["ruby", "nostr-html.rb"]
