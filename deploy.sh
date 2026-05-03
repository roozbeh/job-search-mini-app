#!/bin/bash
set -e

# Usage:
#   ./deploy.sh          — build frontend + deploy API
#   ./deploy.sh api      — deploy API only (skip frontend build)
#   ./deploy.sh web      — build + deploy frontend only

TARGET=${1:-"all"}

echo "==> Deploying JobSearch to jobsearch.ipronto.net... (target: $TARGET)"

# ── Build frontend locally ────────────────────────────────────────────────────
if [ "$TARGET" = "all" ] || [ "$TARGET" = "web" ]; then
  echo "==> Building frontend..."
  npm install --silent
  npm run build
  echo "==> Frontend built → dist/"
fi

# ── Push to server ────────────────────────────────────────────────────────────
if [ "$TARGET" = "all" ] || [ "$TARGET" = "web" ]; then
  echo "==> Uploading dist/ to server..."
  rsync -az --delete dist/ ubuntu@ipronto.net:/home/ubuntu/job-search-mini-app/dist/
fi

if [ "$TARGET" = "all" ] || [ "$TARGET" = "api" ]; then
  ssh ubuntu@ipronto.net << 'EOF'
    set -e
    echo "==> Pulling latest code..."
    cd /home/ubuntu/job-search-mini-app
    git pull

    echo "==> Rebuilding API container..."
    cd backend
    docker-compose up --build -d

    echo "==> Waiting for health check..."
    for i in $(seq 1 30); do
      if curl -sf http://localhost:8001/api/health > /dev/null; then
        echo "==> API is up."
        exit 0
      fi
      echo "    Waiting... ($i/30)"
      sleep 2
    done
    echo "==> ERROR: API did not come up. Logs:"
    docker-compose logs --tail=20
    exit 1
EOF
fi

echo "==> Deploy complete. Visit https://jobsearch.ipronto.net"
