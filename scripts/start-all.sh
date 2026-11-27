#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p .run

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

start_service() {
  local name="$1"
  local jar="$2"
  local heap="$3"
  echo "Starting $name..."
  java -Xmx"$heap" -jar "$jar" > ".run/$name.log" 2>&1 &
  echo "$!" > ".run/$name.pid"
}

./mvnw clean package -DskipTests

start_service eureka-server eureka-server/target/eureka-server-0.0.1-SNAPSHOT.jar 256m
sleep 8
start_service api-gateway api-gateway/target/api-gateway-0.0.1-SNAPSHOT.jar 256m
start_service user-auth-service user-auth-service/target/user-auth-service-0.0.1-SNAPSHOT.jar 384m
start_service finance-ai-service finance-ai-service/target/finance-ai-service-0.0.1-SNAPSHOT.jar 512m

echo "FinSight AI services started. Logs are in $ROOT_DIR/.run/"
