#!/usr/bin/env bash
#
# Business OS — backend test batch runner
#
# Runs the test suite in small feature batches instead of one multi-hour run.
# Fast feedback, isolated failures, and you can stop after any batch without
# losing the results of the ones before it.
#
# Usage (from anywhere):
#   ./test-batches.sh             # run every batch in order
#   ./test-batches.sh unit        # run only the named batch(es)
#   ./test-batches.sh sales billing
#
# Notes:
#   - Unit needs no database. Everything else needs Postgres on localhost:5432
#     (integration tests recreate the businessos_test schema themselves).
#   - The build runs once up front; batches reuse it (--no-build).

set -uo pipefail
cd "$(dirname "$0")"   # now inside backend/

TEST_PROJECT="tests/BusinessOS.Tests"

declare -A BATCHES=(
  [unit]="FullyQualifiedName~Unit"
  [auth]="FullyQualifiedName~AuthFlowTests|FullyQualifiedName~EmailVerificationFlowTests|FullyQualifiedName~InvitationStaffFlowTests|FullyQualifiedName~PlatformHardeningTests|FullyQualifiedName~IdentityEndpointsTests"
  [sales]="FullyQualifiedName~SalesEndpointsTests|FullyQualifiedName~SalesOfflineContractTests|FullyQualifiedName~VoidSaleTests"
  [inventory-pricing]="FullyQualifiedName~InventoryEndpointsTests|FullyQualifiedName~PricingEndpointsTests|FullyQualifiedName~CatalogEndpointsTests"
  [org-identity]="FullyQualifiedName~OrganizationBranchTests|FullyQualifiedName~OnboardingDefaultsTests|FullyQualifiedName~TenantSuspensionTests|FullyQualifiedName~IdentityRepositoryTests|FullyQualifiedName~RoleManagementApplicationTests|FullyQualifiedName~UserManagementApplicationTests"
  [billing]="FullyQualifiedName~BillingEndpointsTests|FullyQualifiedName~FeatureFlagEndpointsTests|FullyQualifiedName~ModulePackagesTests"
  [money]="FullyQualifiedName~CreditEndpointsTests|FullyQualifiedName~CustomerEndpointsTests|FullyQualifiedName~ExpenseEndpointsTests"
  [receipts-dashboard]="FullyQualifiedName~ReceiptEndpointsTests|FullyQualifiedName~DashboardEndpointsTests"
  [lifecycle]="FullyQualifiedName~BusinessLifecycleEndToEndTests"
)

ORDER=(unit auth sales inventory-pricing org-identity billing money receipts-dashboard lifecycle)

run_batch() {
  local name="$1" filter="$2"
  local log="/tmp/opencode/test_batch_${name}.log"
  echo "────────────────────────────────────────"
  echo "▶ ${name}"
  local start=$SECONDS
  dotnet test "$TEST_PROJECT" --no-build --filter "$filter" >"$log" 2>&1
  local summary
  summary=$(grep -E "^(Passed!|Failed!)" "$log" | tail -1)
  if [ -z "$summary" ]; then
    summary="(no result — see $log)"
  fi
  echo "  ${summary}  [${SECONDS}s elapsed, log: $log]"
  # Print failing test names immediately, if any.
  grep -E "^  Failed BusinessOS" "$log" | sed 's/^  Failed /    ✗ /' || true
}

echo "Building test project once..."
dotnet build "$TEST_PROJECT" --warnaserror || {
  echo "Build failed — fix compile errors first."
  exit 1
}

if [ "$#" -gt 0 ]; then
  for name in "$@"; do
    if [ -z "${BATCHES[$name]:-}" ]; then
      echo "Unknown batch: $name (have: ${ORDER[*]})"
      exit 1
    fi
  done
  ORDER=("$@")
fi

FAILED_BATCHES=()
for name in "${ORDER[@]}"; do
  run_batch "$name" "${BATCHES[$name]}"
  if grep -qE "^Failed!" "/tmp/opencode/test_batch_${name}.log"; then
    FAILED_BATCHES+=("$name")
  fi
done

echo "────────────────────────────────────────"
if [ "${#FAILED_BATCHES[@]}" -eq 0 ]; then
  echo "ALL BATCHES GREEN"
else
  echo "Batches with failures: ${FAILED_BATCHES[*]}"
  exit 1
fi
