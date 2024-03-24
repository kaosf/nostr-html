FROM ruby:3.3.0
ENV TZ=Asia/Tokyo
COPY ["Gemfile", "Gemfile.lock", "/"]
RUN bundle config without development && bundle
COPY ["app.rb", "/"]
COPY ["templates", "/templates"]
CMD ["ruby", "/app.rb"]
