#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export SPRING_PROFILES_ACTIVE=prod SERVER_ADDRESS=127.0.0.1 PORT=58192
export DATABASE_URL="${DATABASE_URL:-jdbc:postgresql://127.0.0.1:55439/bodyperfect_preview1}"
export DATABASE_USERNAME="${DATABASE_USERNAME:-audit}" DATABASE_PASSWORD="${DATABASE_PASSWORD:-unused}"
mkdir -p "$ROOT_DIR/.local"
if [[ ! -f "$ROOT_DIR/.local/preview-jwt-secret" ]]; then
  (umask 077; openssl rand -base64 48 > "$ROOT_DIR/.local/preview-jwt-secret")
fi
export JWT_SECRET="${JWT_SECRET:-$(cat "$ROOT_DIR/.local/preview-jwt-secret")}"
export MAIL_HOST=127.0.0.1 MAIL_PORT=1025 MAIL_USERNAME=local@example.test MAIL_PASSWORD=local-only
export SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=false
export SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=false
export SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_REQUIRED=false
export APP_STAFF_COOKIE_SECURE=false
export CORS_ALLOWED_ORIGINS=http://127.0.0.1:5174,http://localhost:5174,http://127.0.0.1:5173,http://localhost:5173
export APP_BOOTSTRAP_ENABLED=false
# Optional ignored server-only AI configuration. Never copied into either frontend.
export SPRING_CONFIG_ADDITIONAL_LOCATION="${SPRING_CONFIG_ADDITIONAL_LOCATION:-optional:file:$ROOT_DIR/.local/ai.properties}"
cd "$ROOT_DIR/clinicapp"
exec java -jar target/ant-backend-0.0.1-SNAPSHOT.jar
