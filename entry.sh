#!/usr/bin/env bash

set -e

[ "$DEBUG" == 'true' ] && set -x

# Generate password if hash not set
if [ ! -z "$FTP_PASSWORD" -a -z "$FTP_PASSWORD_HASH" ]; then
  FTP_PASSWORD_HASH=$(echo "$FTP_PASSWORD" | mkpasswd -s -m sha-512)
fi

if [ ! -z "$FTP_USER" -a ! -z "$FTP_PASSWORD_HASH" ]; then
    /add-virtual-user.sh -d "$FTP_USER" "$FTP_PASSWORD_HASH"
fi
vsftpd
