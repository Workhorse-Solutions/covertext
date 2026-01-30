# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.8
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Install dependencies for amp CLI
RUN apt-get update \
  && apt-get install -y --no-install-recommends jq curl \
  && rm -rf /var/lib/apt/lists/*

# Install amp CLI (installs to /root/.local/bin)
RUN curl -fsSL https://ampcode.com/install.sh | bash

# Ensure binding is always 0.0.0.0
# Binds the server to all IP addresses of the container, so it can be accessed from outside the container.
ENV BINDING="0.0.0.0"

# Ensure amp is on PATH for the vscode user
ENV PATH="/home/vscode/.local/bin:/root/.local/bin:${PATH}"
