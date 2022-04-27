# Start with Ubuntu 20.04 (LTS), and build badsite.io up from there
FROM ubuntu:20.04
MAINTAINER April King <april@twoevils.org>
ARG domain=badsite.io
ARG test_domain=badsite.test
ARG cross_origin_domain=badsite.cross-origin.io
ARG cross_origin_test_domain=badsite.cross-origin.test
EXPOSE 80 443
RUN apt-get update && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && apt-get install -y \
    build-essential \
    git \
    libffi-dev \
    make \
    nginx \
    ruby \
    ruby-dev
RUN gem install jekyll

# Install badsite.io
ADD . badsite.io
WORKDIR badsite.io
RUN make inside-docker DOMAIN=$domain TEST_DOMAIN=$test_domain CROSS_ORIGIN_DOMAIN=$cross_origin_domain CROSS_ORIGIN_TEST_DOMAIN=$sross_origin_test_domain

# Start things up!
CMD nginx && tail -f /var/log/nginx/access.log /var/log/nginx/error.log
