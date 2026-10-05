#!/usr/bin/env bash
#
# Business OS — local PRE-PRODUCTION runner
#
# Starts the API and the Workers host together under the LocalPreProduction
# environment against the PRE-PROD database (businessos_preprod). Works the
# same as run-dev.sh but talks to pre-prod data, so you can test real flows
# (e.g. resetting passwords on your pre-prod account) with emails going to
# MailHog on 127.0.0.1:1025.
#
# Requires:
#   - Postgres running (businessos_preprod database exists)
#   - MailHog on 127.0.0.1:1025
#   - A JWT secret (see below)
#
# Usage: ./run-prepro.sh   (from the repo root, or anywhere in the repo).
# If you have no secret exported, this script generates a fresh one and prints
# it so you can log in again afterwards (JWT is independent of stored users).

set -euo pipefail

cd "$(dirname "$0")"   # now inside backend/

API_PROJECT="src/API/BusinessOS.API.csproj"
WORKER_PROJECT="src/Workers/BusinessOS.Workers.csproj"
API_ENVIRONMENT="LocalPreProduction"
WORKER_ENVIRONMENT="LocalPreProduction"

# PRE-PROD database connection.
if [[ -z "${ConnectionStrings__Default:-}" ]]; then
  export ConnectionStrings__Default='Host=localhost;Port=5432;Database=businessos_preprod;Username=businessos;Password=Joseph662.'
  echo "Using pre-prod DB: businessos_preprod (from default)."
fi

# JWT secret — required. Use exported value, or generate one.
if [[ -z "${Jwt__Secret:-}" ]]; then
  export Jwt__Secret="$(openssl rand -base64 48)"
  echo "Generated a new JWT secret. Log back in afterward — JWT does not depend on stored users."
fi

# Force email to MailHog (LocalPreProduction config has no Smtp section, so it
# would otherwise fall back to real SMTP on port 587).
export Smtp__Host="${Smtp__Host:-127.0.0.1}"
export Smtp__Port="${Smtp__Port:-1025}"
export Smtp__UseStartTls=false

LOG_DIR="logs"
mkdir -p "$LOG_DIR"
API_LOG="$LOG_DIR/api-prepro.log"
WORKER_LOG="$LOG_DIR/workers-prepro.log"

cleanup() {
  echo
  echo "Stopping API and Workers..."
  kill "${API_PID:-}" "${WORKER_PID:-}" 2>/dev/null || true
  wait "${API_PID:-}" "${WORKER_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Starting API (LocalPreProduction -> http://localhost:5000) -> $API_LOG"
ASPNETCORE_ENVIRONMENT="$API_ENVIRONMENT" \
  dotnet run --project "$API_PROJECT" --no-launch-profile >"$API_LOG" 2>&1 &
API_PID=$!

echo "Starting Workers (outbox/email) -> $WORKER_LOG"
DOTNET_ENVIRONMENT="$WORKER_ENVIRONMENT" \
  dotnet run --project "$WORKER_PROJECT" --no-launch-profile >"$WORKER_LOG" 2>&1 &
WORKER_PID=$!

echo
echo "Ctrl+C to stop both. Tailing combined output..."
tail -F "$API_LOG" "$WORKER_LOG" 2>/dev/null || true
