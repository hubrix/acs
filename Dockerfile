# syntax=docker/dockerfile:1
# check=error=true

# Production image. For development use bin/dev (Postgres on the host) or
# docker compose up (Postgres in a container).
#
#   docker build -t acs .
#   docker run -d -p 3000:3000 \
#     -e RAILS_MASTER_KEY=<config/master.key> \
#     -e DATABASE_URL=postgres://user:pass@host/acs_production \
#     --name acs acs

ARG RUBY_VERSION=4.0.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Packages needed at run time.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Build stage: compiles gems and precompiles assets, then is thrown away.
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# .ruby-version is copied too: the Gemfile reads the version from it.
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# config/app.yml holds LDAP and mail settings and is not in the repo; the
# example is enough to satisfy the initializers during precompile.
RUN cp -n config/app.yml.example config/app.yml || true

# Compile the SCSS and digest the assets. SECRET_KEY_BASE_DUMMY lets this run
# without the real credentials.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails dartsass:build assets:precompile

# Final image.
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as an unprivileged user.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# 3000 rather than 80: the image runs as a non-root user, which cannot bind a
# privileged port under every container runtime.
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
