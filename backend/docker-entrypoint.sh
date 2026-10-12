#!/usr/bin/env bash
set -euo pipefail

# Render/Koyeb set PORT explicitly; Hugging Face Spaces defaults to 7860.
export ASPNETCORE_URLS="http://0.0.0.0:${PORT:-7860}"
export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Production}"
export DOTNET_ENVIRONMENT="${DOTNET_ENVIRONMENT:-$ASPNETCORE_ENVIRONMENT}"
export HOME="${HOME:-/tmp}"

# Keep GC memory footprint bounded inside free-tier containers.
export DOTNET_gcServer=0

echo "Starting BusinessOS.Workers in background..."
dotnet /app/workers/BusinessOS.Workers.dll &
WORKER_PID=$!

trap 'kill "$WORKER_PID" 2>/dev/null || true' EXIT INT TERM

echo "Starting BusinessOS.API on ${ASPNETCORE_URLS} (${ASPNETCORE_ENVIRONMENT})..."
exec dotnet /app/api/BusinessOS.API.dll
