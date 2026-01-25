# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.3.5
FROM ruby:$RUBY_VERSION

# Install packages needed for development
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    postgresql-client \
    libvips \
    nodejs \
    npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set up working directory
WORKDIR /workspaces/covertext

# Install bundler
RUN gem update --system && gem install bundler

USER $USERNAME
