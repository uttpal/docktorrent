FROM debian:jessie

MAINTAINER kfei <kfei@kfei.net>

ENV VER_LIBTORRENT 0.13.4
ENV VER_RTORRENT 0.9.4

WORKDIR /usr/local/src

# This long disgusting instruction saves your image ~130 MB
RUN build_deps="automake build-essential ca-certificates libc-ares-dev libcppunit-dev libtool"; \
    build_deps="${build_deps} libssl-dev libxml2-dev libncurses5-dev pkg-config subversion wget"; \
    set -x && \
    apt-get update && apt-get install -q -y --no-install-recommends ${build_deps} && \
    wget http://curl.haxx.se/download/curl-7.39.0.tar.gz && \
    tar xzvfp curl-7.39.0.tar.gz && \
    cd curl-7.39.0 && \
    ./configure --enable-ares --enable-tls-srp --enable-gnu-tls --with-zlib --with-ssl && \
    make && \
    make install && \
    cd .. && \
    rm -rf curl-* && \
    ldconfig && \
    apt-get -y install libxmlrpc-core-c3 libxmlrpc-core-c3-dev && \
    wget -O libtorrent-$VER_LIBTORRENT.tar.gz https://github.com/rakshasa/libtorrent/archive/$VER_LIBTORRENT.tar.gz && \
    tar xzf libtorrent-$VER_LIBTORRENT.tar.gz && \
    cd libtorrent-$VER_LIBTORRENT && \
    ./autogen.sh && \
    ./configure --with-posix-fallocate && \
    make && \
    make install && \
    cd .. && \
    rm -rf libtorrent-* && \
    ldconfig && \
    wget -O rtorrent-$VER_RTORRENT.tar.gz https://github.com/rakshasa/rtorrent/archive/$VER_RTORRENT.tar.gz && \
    tar xzf rtorrent-$VER_RTORRENT.tar.gz && \
    cd rtorrent-$VER_RTORRENT && \
    ./autogen.sh && \
    ./configure --with-xmlrpc-c --with-ncurses && \
    make && \
    make install && \
    cd .. && \
    rm -rf rtorrent-* && \
    ldconfig && \
    mkdir -p /usr/share/nginx/html && \
    cd /usr/share/nginx/html && \
    mkdir rutorrent && \
    curl -L -O https://github.com/Novik/ruTorrent/archive/master.tar.gz && \
    tar xzvf master.tar.gz -C rutorrent --strip-components 1 && \
    rm -rf *.tar.gz && \
    apt-get purge -y --auto-remove ${build_deps} && \
    apt-get autoremove -y

# Install required packages
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    apache2-utils \
    libc-ares2 \
    nginx \
    php5-cli \
    php5-fpm

# Install packages for ruTorrent plugins
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    mediainfo \
    unrar-free \
    unzip

# For ffmpeg, which is required by the ruTorrent screenshots plugin
# This increases ~53 MB of the image size, remove it if you really don't need screenshots
RUN echo "deb http://www.deb-multimedia.org jessie main" >> /etc/apt/sources.list && \
    apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys A401FF99368FA1F98152DE755C808C2B65558117 && \
    apt-get update && apt-get install -q -y --no-install-recommends \
    deb-multimedia-keyring \
    ffmpeg

# IMPORTANT: Change the default login/password of ruTorrent before build
RUN htpasswd -cb /usr/share/nginx/html/rutorrent/.htpasswd docktorrent p@ssw0rd

# Copy config files
COPY config/nginx/default /etc/nginx/sites-available/default
COPY config/rtorrent/.rtorrent.rc /root/.rtorrent.rc
COPY config/rutorrent/config.php /usr/share/nginx/html/rutorrent/conf/config.php

# Add the s6 binaries fs layer
ADD s6-1.1.3.2-musl-static.tar.xz /

# Service directories and the wrapper script
COPY rootfs /

RUN groupadd -g 48 ftp && \
    useradd --no-create-home --home-dir /rtorrent -s /bin/false --uid 48 --gid 48 -c 'ftp daemon' ftp

RUN apt-get update \
    && apt-get install -y --no-install-recommends vsftpd db5.3-util whois \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/vsftpd/empty /etc/vsftpd/user_conf /var/ftp /rtorrent && \
    touch /var/log/vsftpd.log && \
    rm -rf /rtorrent/ftp

COPY vsftpd*.conf /etc/
COPY vsftpd_virtual /etc/pam.d/
COPY *.sh /


# Run the wrapper script first
RUN apt-get update && apt-get install -y supervisor # Installing supervisord

ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENTRYPOINT ["/usr/bin/supervisord"]

# Declare ports to expose
EXPOSE 80 9527 45566 21 4559 4560 4561 4562 4563 4564

# Declare volumes
VOLUME ["/rtorrent","/etc/vsftpd"]

# This should be removed in the latest version of Docker
ENV HOME /root
