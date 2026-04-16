#!/bin/bash
# Run this ONCE on your AWS server to get the first SSL certificate.
# After this, certbot renews automatically via the docker-compose certbot service.

DOMAIN="jobsearch.ipronto.net"
EMAIL="ruzbeh@gmail.com"   # change if needed

set -e

echo "==> Starting nginx (HTTP only) for ACME challenge..."
# Temporarily use a plain HTTP nginx config
docker compose up -d nginx

echo "==> Requesting certificate for $DOMAIN..."
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN"

echo "==> Reloading nginx with SSL config..."
docker compose exec nginx nginx -s reload

echo "==> Done. Certificate is at /etc/letsencrypt/live/$DOMAIN/"
echo "    Auto-renewal is handled by the certbot service in docker-compose."
