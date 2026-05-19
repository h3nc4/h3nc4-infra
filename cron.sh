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

# --- CONFIG ---
REPO_DIR="$(CDPATH="" cd -- "$(dirname -- "$0")" && pwd)"
LOG_FILE="/var/log/home-server-deploy.log"
LOCK_FILE="/tmp/home-server-deploy.lock"
SSH_KEY_PATH="/home/dev/.ssh/id_deploy"

# --- LOGGING ---
exec >>"${LOG_FILE}" 2>&1
log() {
  printf "[%s] %s\n" "$(date -Is || :)" "$1"
}
cleanup() {
  EXIT_CODE=$?
  if [ "${EXIT_CODE}" -ne 0 ]; then
    log "Deployment failed with exit code ${EXIT_CODE}"
  fi
  rm -f "${LOCK_FILE}"
}
trap cleanup EXIT

# --- LOCK ---
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  log "Another deployment is running, exiting."
  exit 0
fi

log "Starting deployment run"

# --- SSH CONFIG ---
if [ -f "${SSH_KEY_PATH}" ]; then
  export GIT_SSH_COMMAND="ssh -i ${SSH_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"
else
  log "Warning: Deploy key not found at ${SSH_KEY_PATH}."
fi

cd "${REPO_DIR}"

UPSTREAM_REF=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}") || {
  log "Error: current branch has no upstream configured"
  exit 1
}

# --- FETCH UPDATES ---
git fetch origin || { 
  log "Error: git fetch failed"
  exit 1
}

LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse "${UPSTREAM_REF}")"

if [ "${LOCAL_HEAD}" = "${REMOTE_HEAD}" ]; then
  log "No changes detected, exiting."
  exit 0
fi

log "Changes detected, pulling updates"
git pull --ff-only

# --- DEPLOY ---
log "Running docker compose pull"
docker compose pull

log "Running docker compose up"
docker compose up -d --wait --remove-orphans

log "Deployment finished successfully"
