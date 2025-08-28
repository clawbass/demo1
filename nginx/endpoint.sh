#!/bin/sh
set -eu
mkdir -p /etc/nginx/auth
# If pass-through user/pass are provided, create htpasswd dynamically
if [ -n "${BASIC_AUTH_USER:-}" ] && [ -n "${BASIC_AUTH_PASS:-}" ]; then
  htpasswd -bc /etc/nginx/auth/.htpasswd "$BASIC_AUTH_USER" "$BASIC_AUTH_PASS"
elif [ -n "${BASIC_AUTH_LINE:-}" ]; then
  echo "$BASIC_AUTH_LINE" > /etc/nginx/auth/.htpasswd
else
  echo "ERROR: BASIC_AUTH_USER/BASIC_AUTH_PASS or BASIC_AUTH_LINE must be set" >&2
  exit 1
fi
exec nginx -g "daemon off;"
