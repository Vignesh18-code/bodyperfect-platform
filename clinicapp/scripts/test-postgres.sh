#!/usr/bin/env bash
set -euo pipefail
# Supply an empty disposable database only. This script never creates/drops databases.
: "${TEST_DATABASE_URL:?Set TEST_DATABASE_URL to an empty disposable PostgreSQL database}"
: "${TEST_DATABASE_USERNAME:?Set TEST_DATABASE_USERNAME}"
: "${TEST_DATABASE_PASSWORD:=}"
cd "$(dirname "$0")/.."
mvn "$@" test \
  -Dspring.datasource.url="$TEST_DATABASE_URL" \
  -Dspring.datasource.username="$TEST_DATABASE_USERNAME" \
  -Dspring.datasource.password="$TEST_DATABASE_PASSWORD" \
  -Dspring.datasource.driver-class-name=org.postgresql.Driver \
  -Dspring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect \
  -Dspring.jpa.hibernate.ddl-auto=validate \
  -Dspring.flyway.enabled=true
