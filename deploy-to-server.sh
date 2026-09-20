#!/bin/bash
# ============================================================
# EcaAfrica — Full Deployment Script
# Server: root@169.58.124.150
# Run FROM the server:
#   ssh root@169.58.124.150
#   curl -sL https://raw.githubusercontent.com/MbarushimanaFabrice/Ecareafrica_backend/main/deployment/linux/deploy-production.sh | bash
# OR copy-paste this whole file then: bash deploy-to-server.sh
# ============================================================

set -e

BACKEND_REPO="https://github.com/MbarushimanaFabrice/Ecareafrica_backend.git"
FRONTEND_REPO="https://github.com/MbarushimanaFabrice/Ecareafrica_frontend.git"
BACKEND_BRANCH="main"
FRONTEND_BRANCH="main"
BACKEND_DIR="/var/www/ecare/backend"
FRONTEND_DIR="/var/www/ecare/frontend"

echo "============================================"
echo "  EcaAfrica Deployment"
echo "  Backend  branch : $BACKEND_BRANCH"
echo "  Frontend branch : $FRONTEND_BRANCH"
echo "============================================"

# ── 1. Stop PM2 ──────────────────────────────────────────────
echo ""
echo "[1/10] Stopping PM2..."
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
fuser -k 5500/tcp 2>/dev/null || true
fuser -k 4173/tcp 2>/dev/null || true
echo "✓ PM2 stopped, ports freed"

# ── 2. Pull / clone backend ───────────────────────────────────
echo ""
echo "[2/10] Pulling backend ($BACKEND_BRANCH)..."
mkdir -p "$(dirname $BACKEND_DIR)"
if [ -d "$BACKEND_DIR/.git" ]; then
  cd "$BACKEND_DIR"
  git fetch origin
  git checkout "$BACKEND_BRANCH"
  git reset --hard "origin/$BACKEND_BRANCH"
else
  rm -rf "$BACKEND_DIR"
  git clone -b "$BACKEND_BRANCH" "$BACKEND_REPO" "$BACKEND_DIR"
  cd "$BACKEND_DIR"
fi
echo "✓ Backend pulled — $(git log --oneline -1)"

# ── 3. Write backend .env ─────────────────────────────────────
echo ""
echo "[3/10] Writing backend .env..."
cat > "$BACKEND_DIR/.env" << 'ENVEOF'
DATABASE_URL="postgresql://postgres:2211@localhost:5432/ecareafrica?schema=public"

JWT_SECRET=1b1a90a340949c666a212b212de76a9c7e14d24a5cd9c6b1de32d517668501b1
JWT_REFRESH_SECRET=hk3BkIhG-cEMddfdK3FIGsAgRL_16mQWxKDgnaRvdRwzbWC9ICwhQO0Kashg-DQEWjCnKz3tpxaG-K9Y2gyHrg
PLATFORM_JWT_SECRET=Gqwfm4cF1q3S2uX5nvdRkUZRQU40ZmcGRCBs4H666mgez6mNaU5iS7Mhjo3wSvKssqV2Sa0B7sFOk49181MEEw
PLATFORM_JWT_REFRESH_SECRET=CL3gr3UNYYqfdcs8zdzvbMWkLn3rFRQn_BbkxOfOgFy1
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

PORT=5500
NODE_ENV=production
TZ=Africa/Kigali
TRUST_PROXY=true

CORS_ORIGIN=https://ecareafrica.net,https://www.ecareafrica.net,https://backend.ecareafrica.net

RATE_LIMIT_ENABLED=true
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100

S3_ENDPOINT=https://abcd1234efgh.r2.cloudflarestorage.com
S3_REGION=auto
S3_BUCKET=ecareafrica-storage
S3_ACCESS_KEY_ID=RboLlUqEo8Ojh9ALgoWC_yzWuVeZFoN2dlX4XKZ0eCZh7g
S3_SECRET_ACCESS_KEY=RboLlUqEo8Ojh9ALgoWC_yzWuVeZFoN2dlX4XKZ0eCZh7g
S3_PUBLIC_URL=https://pub.r2.dev

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=netrackdevelopement@gmail.com
SMTP_PASS=elkrdmcpmksazazy
SMTP_FROM=netrackdevelopement@gmail.com

REDIS_URL=redis://localhost:6379

SMS_UGANDA_API_URL=http://text.emediauganda.com/api.php
SMS_UGANDA_USER=your_username
SMS_UGANDA_PASSWORD=your_password
SMS_UGANDA_SENDER=EducationCare

APP_BASE_URL=https://ecareafrica.net

WG_CONF_PATH=/etc/wireguard/wg0.conf
WG_PUBKEY_PATH=/etc/wireguard/server_public.key
WG_INTERFACE=wg0
VPN_SUBNET=10.0
VPN_CIDR=16
SERVER_VPN_IP=10.0.0.1
SERVER_PUBLIC_IP=169.58.124.150
WG_PORT=51820

PULL_CONCURRENCY=10
PULL_LOGS_INTERVAL_MS=5000
PULL_TIMEOUT_MS=20000
SSE_CONNECT_CONCURRENCY=10
SSE_CONNECT_STAGGER_MS=200
SSE_DEDUP_CACHE_SIZE=10000
ENVEOF
echo "✓ Backend .env written (PORT=5500)"

# ── 4. Backend: install, prisma, build ───────────────────────
echo ""
echo "[4/10] Installing backend dependencies..."
cd "$BACKEND_DIR"
npm install --production=false
echo "✓ Dependencies installed"

echo ""
echo "[5/10] Prisma generate + migrate..."
npx prisma generate --schema src/models/schema.prisma
npx prisma migrate deploy --schema src/models/schema.prisma
echo "✓ Prisma ready"

echo ""
echo "[6/10] Building backend..."
npm run build
echo "✓ Backend built → dist/server.js"

# ── 5. Pull / clone frontend ──────────────────────────────────
echo ""
echo "[7/10] Pulling frontend ($FRONTEND_BRANCH)..."
mkdir -p "$(dirname $FRONTEND_DIR)"
if [ -d "$FRONTEND_DIR/.git" ]; then
  cd "$FRONTEND_DIR"
  git fetch origin
  git checkout "$FRONTEND_BRANCH"
  git reset --hard "origin/$FRONTEND_BRANCH"
else
  rm -rf "$FRONTEND_DIR"
  git clone -b "$FRONTEND_BRANCH" "$FRONTEND_REPO" "$FRONTEND_DIR"
  cd "$FRONTEND_DIR"
fi
echo "✓ Frontend pulled — $(git log --oneline -1)"

echo "VITE_API_BASE_URL=https://backend.ecareafrica.net/api/v1" > "$FRONTEND_DIR/.env"

cd "$FRONTEND_DIR"
npm install
npm run build
echo "✓ Frontend built → $FRONTEND_DIR/dist/"

# ── 6. Start with PM2 ────────────────────────────────────────
echo ""
echo "[8/10] Starting backend with PM2 (ecosystem.config.js)..."
cd "$BACKEND_DIR"
pm2 start ecosystem.config.js --env production

echo "Starting frontend static server on port 4173..."
pm2 serve "$FRONTEND_DIR/dist" 4173 --name "ecare-frontend" --spa --time

pm2 save
pm2 startup 2>/dev/null || true
echo "✓ PM2 processes running"

# ── 7. Install / update nginx config ─────────────────────────
echo ""
echo "[9/10] Updating nginx config..."
NGINX_CONF="$BACKEND_DIR/deployment/linux/ecareafrica-nginx.conf"
if [ -f "$NGINX_CONF" ]; then
  cp "$NGINX_CONF" /etc/nginx/sites-available/ecareafrica
  ln -sf /etc/nginx/sites-available/ecareafrica /etc/nginx/sites-enabled/ecareafrica
  # Remove default site if present (conflicts on port 80)
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && nginx -s reload
  echo "✓ Nginx updated and reloaded"
else
  echo "⚠ nginx conf not found at $NGINX_CONF — skipping"
fi

# ── 8. Done ───────────────────────────────────────────────────
echo ""
echo "[10/10] Done!"
echo ""
pm2 list
echo ""
echo "  Frontend  → https://ecareafrica.net"
echo "  Backend   → https://backend.ecareafrica.net/api/v1"
echo ""
echo "Logs:  pm2 logs ecare-backend"
echo "       pm2 logs ecare-frontend"
