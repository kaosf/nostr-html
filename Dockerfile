FROM ruby:3.3.4
COPY ["Gemfile", "Gemfile.lock", "/"]
RUN bundle config without development && bundle
COPY ["setup.sql", "/"]
COPY ["app.rb", "/nostr-html.rb"]
COPY ["templates", "/templates"]
CMD ["ruby", "nostr-html.rb"]
