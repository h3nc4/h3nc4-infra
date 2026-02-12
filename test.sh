#!/bin/sh
# Copyright (C) 2025-2026  Henrique Almeida
# This file is part of h3nc4-compose.
#
# h3nc4-compose is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# h3nc4-compose is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with h3nc4-compose.  If not, see <https://www.gnu.org/licenses/>.
set -e

echo "Starting connectivity tests..."

wait_for() {
  echo "Checking $1:$2..."
  for _ in $(seq 1 30); do
    if nc -z -w 1 "$1" "$2"; then
      echo "$1:$2 is up."
      return 0
    fi
    sleep 1
  done
  echo "$1:$2 failed to start." >&2
  exit 1
}

check_http() {
  echo "Checking $1..."
  if wget -qO- "http://$1" | grep -qi h3nc4; then
    echo "$1 OK"
  else
    echo "$1 FAILED" >&2
    exit 1
  fi
}

check_dns_block() {
  if ! nslookup dns >/dev/null 2>&1; then
    exit 0
  fi
  echo "Checking DNS block for $1..."
  if nslookup "$1" dns 2>/dev/null | grep -q "0.0.0.0"; then
    echo "$1 blocked"
  else
    echo "DNS block for $1 FAILED" >&2
    exit 1
  fi
}

# Wait for services to be ready
if nslookup dns >/dev/null 2>&1; then
  wait_for dns 53
fi
wait_for h3nc4 80
wait_for wasudoku 80
wait_for cgit 80
wait_for maddy 25
wait_for tor-reverse-proxy 80

echo "Running HTTP smoke tests..."

check_http h3nc4
check_http wasudoku
check_http cgit

echo "Running DNS tests..."
check_dns_block google.com

echo "All tests passed successfully."

touch /healthy

CI=${CI:-"false"}
if [ "${CI}" = "true" ]; then
  exit 0
fi

cleanup() {
  kill "${child}"
  exit 0
}
trap cleanup TERM INT
sleep infinity &
child=$!
wait "${child}"
