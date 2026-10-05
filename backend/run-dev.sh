#!/usr/bin/env bash
#
# Business OS — local development runner
#
# Starts the API and the Workers host together so outbox-backed work (email
# verification codes, password resets, scheduled jobs, etc.) is actually
# delivered. Without the Workers host running, the Postgres outbox is never
# drained and outbox-only emails never reach MailHog.
#
# Prereqs: .NET SDK, Postgres (see ADR-0009 / docs/TechStack.md), MailHog on
# 127.0.0.1:1025.
#
# Usage: ./run-dev.sh   (run from the repo root, or from anywhere in the repo)

set -euo pipefail

cd "$(dirname "$0")"   # now inside backend/

API_PROJECT="src/API/BusinessOS.API.csproj"
WORKER_PROJECT="src/Workers/BusinessOS.Workers.csproj"
API_ENVIRONMENT="Development"
WORKER_ENVIRONMENT="Development"

LOG_DIR="logs"
mkdir -p "$LOG_DIR"
API_LOG="$LOG_DIR/api.log"
WORKER_LOG="$LOG_DIR/workers.log"

# Both projects read ConnectionStrings/Jwt/Smtp from their own
# appsettings.Development.json. Set DATABASE_URL only if you want to override
# the DB connection for both processes.
if [[ -n "${DATABASE_URL:-}" ]]; then
  export ConnectionStrings__Default="$DATABASE_URL"
fi

cleanup() {
  echo
  echo "Stopping API and Workers..."
  kill "${API_PID:-}" "${WORKER_PID:-}" 2>/dev/null || true
  wait "${API_PID:-}" "${WORKER_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Starting API (http://localhost:5000) -> $API_LOG"
ASPNETCORE_ENVIRONMENT="$API_ENVIRONMENT" \
  dotnet run --project "$API_PROJECT" >"$API_LOG" 2>&1 &
API_PID=$!

echo "Starting Workers (outbox/email) -> $WORKER_LOG"
DOTNET_ENVIRONMENT="$WORKER_ENVIRONMENT" \
  dotnet run --project "$WORKER_PROJECT" >"$WORKER_LOG" 2>&1 &
WORKER_PID=$!

echo
echo "Ctrl+C to stop both. Tailing combined output..."
tail -F "$API_LOG" "$WORKER_LOG" 2>/dev/null || true
