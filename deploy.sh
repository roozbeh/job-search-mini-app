#!/bin/bash
set -e

# Usage:
#   ./deploy.sh        — pull latest code and rebuild API container

echo "==> Deploying JobSearch to jobsearch.ipronto.net..."

ssh ubuntu@ipronto.net << EOF
  set -e
  echo "==> Pulling latest code..."
  cd /home/ubuntu/job-search-mini-app
  git pull

  echo "==> Rebuilding API container..."
  cd backend
  docker-compose up --build -d

  echo "==> Waiting for health check..."
  for i in \$(seq 1 30); do
    if curl -sf http://localhost:8001/health > /dev/null; then
      echo "==> API is up."
      break
    fi
    echo "    Waiting... (\$i/30)"
    sleep 2
  done
EOF

echo "==> Deploy complete. Visit https://jobsearch.ipronto.net"
