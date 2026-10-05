#!/usr/bin/env bash
set -euo pipefail
# Operator-invoked: briefly stops API writes. Requires age and an off-host recipient key.
[[ "${1:-}" == "--maintenance" ]] || { echo 'Usage: AGE_RECIPIENT=age1... BACKUP_DIR=/secure/path ./scripts/backup-production.sh --maintenance'; exit 2; }
: "${AGE_RECIPIENT:?Set the off-host age recipient public key}"
: "${BACKUP_DIR:?Set an absolute backup destination outside the repository}"
[[ "$BACKUP_DIR" == /* ]] || { echo 'BACKUP_DIR must be absolute'; exit 2; }
command -v age >/dev/null
cd "$(dirname "$0")/.."
case "$BACKUP_DIR/" in "$PWD/"*) echo 'Backups must be outside the repository'; exit 2;; esac
umask 077
mkdir -p "$BACKUP_DIR"
archive=$(mktemp -d "$BACKUP_DIR/bodyperfect-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
compose=(docker compose --env-file infrastructure/.env -f infrastructure/compose.production.yaml)
# Validate public-key encryption before interrupting API service.
printf 'validation' | age -r "$AGE_RECIPIENT" -o "$archive/check.age"
rm "$archive/check.age"
"${compose[@]}" stop api
trap '"${compose[@]}" start api' EXIT
"${compose[@]}" exec -T database pg_dump -U clinicapp -d clinicapp -Fc | age -r "$AGE_RECIPIENT" -o "$archive/database.dump.age"
"${compose[@]}" run --rm --no-deps -T --entrypoint tar api -czf - -C /app uploads | age -r "$AGE_RECIPIENT" -o "$archive/uploads.tar.gz.age"
# Marker is written only after both encrypted streams completed successfully.
printf 'Database and uploads complete. Preserve the encryption key separately.\n' > "$archive/COMPLETE"
echo "Encrypted backup saved to $archive. Copy it off this host and verify a restore."
