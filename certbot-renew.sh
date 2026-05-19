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
set -eu

REPO_DIR="$(CDPATH="" cd -- "$(dirname -- "$0")" && pwd)"
LOG_FILE="/var/log/home-server-certbot-renew.log"
LOCK_FILE="/tmp/home-server-certbot-renew.lock"

exec >>"${LOG_FILE}" 2>&1

log() {
  printf "[%s] %s\n" "$(date -Is || :)" "$1"
}

cleanup() {
  exit_code=$?
  if [ "${exit_code}" -ne 0 ]; then
    log "Certbot renewal failed with exit code ${exit_code}"
  fi
  rm -f "${LOCK_FILE}"
}

trap cleanup EXIT

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  log "Another certbot renewal is already running, exiting."
  exit 0
fi

log "Starting certbot renewal run"

cd "${REPO_DIR}"

docker run --rm \
  -v "${PWD}/data/certbot/certs/:/etc/letsencrypt/" \
  -v "${PWD}/data/certbot/logs/:/var/log/letsencrypt/" \
  -p 80:80 \
  certbot/certbot renew --standalone

log "Restarting maddy to pick up renewed certificates"
docker compose restart maddy

log "Certbot renewal run finished successfully"
