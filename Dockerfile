FROM ruby:3.3.0
COPY ["Gemfile", "Gemfile.lock", "/"]
RUN bundle config without development && bundle
COPY ["setup.sql", "app.rb", "/"]
COPY ["templates", "/templates"]
CMD ["ruby", "/app.rb"]
