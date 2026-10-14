#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/src/API"

export ASPNETCORE_URLS="http://0.0.0.0:5055"
export ASPNETCORE_ENVIRONMENT="Production"
export DOTNET_ENVIRONMENT="Production"
export ConnectionStrings__Default="Host=ep-damp-firefly-b95bmvnp.c-7.eu-central-1.aws.neon.tech;Database=neondb;Username=neondb_owner;Password=npg_FN8nf1gOeVXM;SSL Mode=Require;Trust Server Certificate=true"
export Jwt__Secret="JolinxProdJwtSecretKey2026MultiCloudFailoverHighAvailability9988"
export Jwt__Issuer="businessos"
export Jwt__Audience="businessos-clients"
export Jwt__AccessTokenMinutes="15"
export Security__TwoFactorEncryptionKey="JolinxProdTwoFactorKey2026MultiCloudFailover32ByteSecretKey9988"

echo "=========================================================="
echo " Starting Jolinx Backend on http://localhost:5055"
echo " Connected to Neon PostgreSQL 17"
echo "=========================================================="

exec dotnet "$DIR/src/API/bin/Debug/net10.0/BusinessOS.API.dll"
