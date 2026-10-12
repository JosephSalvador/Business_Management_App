#!/usr/bin/env bash
set -euo pipefail

# Render sets PORT (default 10000); default to 8080 if not provided.
export ASPNETCORE_URLS="http://0.0.0.0:${PORT:-8080}"
export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Production}"
export DOTNET_ENVIRONMENT="${DOTNET_ENVIRONMENT:-$ASPNETCORE_ENVIRONMENT}"

# Keep GC memory footprint bounded inside 512 MB free-tier containers.
export DOTNET_gcServer=0

echo "Starting BusinessOS.Workers in background..."
dotnet /app/workers/BusinessOS.Workers.dll &
WORKER_PID=$!

trap 'kill "$WORKER_PID" 2>/dev/null || true' EXIT INT TERM

echo "Starting BusinessOS.API on ${ASPNETCORE_URLS} (${ASPNETCORE_ENVIRONMENT})..."
exec dotnet /app/api/BusinessOS.API.dll
