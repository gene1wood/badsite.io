# Start with Ubuntu 20.04 (LTS), and build badsite.io up from there
FROM ubuntu:20.04
MAINTAINER April King <april@twoevils.org>
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
RUN make inside-docker

# Start things up!
CMD nginx && tail -f /var/log/nginx/access.log /var/log/nginx/error.log
