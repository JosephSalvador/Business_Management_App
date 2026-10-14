#!/usr/bin/env bash
set -e

# ==============================================================================
# Jolinx Business OS — Deploy Flutter Web to Cloudflare Pages (100% Free)
# Environments:
#   - Staging (Default, Safe):  branch "staging" -> https://staging.jolinx-app.pages.dev
#   - Production (--prod flag): branch "main"    -> https://app.joberthix.xyz
# ==============================================================================

PROJECT_NAME="${CLOUDFLARE_PAGES_PROJECT:-jolinx-app}"
CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-f30c28de87437abbe6b487082c163cc0}"

# Target environment flag parsing
TARGET_ENV="staging"
CF_BRANCH="staging"

for arg in "$@"; do
  case $arg in
    --prod|--production)
      TARGET_ENV="production"
      CF_BRANCH="main"
      shift
      ;;
    --staging)
      TARGET_ENV="staging"
      CF_BRANCH="staging"
      shift
      ;;
  esac
done

echo "=========================================================="
echo " Deploying Jolinx Web App to Cloudflare Pages"
echo " Project:     $PROJECT_NAME"
echo " Account ID:  $CLOUDFLARE_ACCOUNT_ID"
echo " Environment: $TARGET_ENV (Branch: $CF_BRANCH)"
if [ "$TARGET_ENV" = "production" ]; then
  echo " 🚨 WARNING: Deploying directly to LIVE PRODUCTION STORES!"
else
  echo " 🛡️ SAFE MODE: Deploying to Staging Preview (Live stores untouched)"
fi
echo "=========================================================="

# Check if build/web exists or if release zip exists
DEPLOY_DIR="build/web"

if [ ! -d "$DEPLOY_DIR" ]; then
  if [ -f "jolinx-web.zip" ]; then
    echo "Found jolinx-web.zip! Unpacking to temporary directory..."
    mkdir -p /tmp/jolinx-web-deploy
    unzip -q -o jolinx-web.zip -d /tmp/jolinx-web-deploy
    DEPLOY_DIR="/tmp/jolinx-web-deploy"
  else
    echo "build/web directory not found."
    echo "You can either:"
    echo "  1. Download jolinx-web.zip from the latest GitHub Release"
    echo "     (https://github.com/JosephSalvador/Business_Management_App/releases/tag/latest)"
    echo "  2. Or run: flutter build web --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.joberthix.xyz"
    exit 1
  fi
fi

# Ensure SPA routing files are present in the deploy directory
cp web/_redirects "$DEPLOY_DIR/_redirects" 2>/dev/null || echo "/*  /index.html  200" > "$DEPLOY_DIR/_redirects"
cp web/_headers "$DEPLOY_DIR/_headers" 2>/dev/null || true

echo "Uploading files to Cloudflare Pages (Branch: $CF_BRANCH)..."
CLOUDFLARE_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID" npx wrangler pages deploy "$DEPLOY_DIR" --project-name="$PROJECT_NAME" --branch="$CF_BRANCH"

echo ""
echo "=========================================================="
echo " Web app deployed successfully to Cloudflare Pages!"
if [ "$TARGET_ENV" = "production" ]; then
  echo " Live Production URL: https://app.joberthix.xyz"
  echo " Cloudflare Canonical: https://${PROJECT_NAME}.pages.dev"
else
  echo " Safe Staging Preview URL: https://staging.${PROJECT_NAME}.pages.dev"
  echo " (To promote to live production, run with --prod)"
fi
echo "=========================================================="
