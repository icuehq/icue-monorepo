#!/usr/bin/env bash
# Local emulator suite (auth, firestore, functions, storage) with persisted data.
#   emulators.sh start   build Functions, load .emulator-data if present, save to it on exit (Ctrl-C)
#   emulators.sh reset   delete the saved data
#   emulators.sh seed    seed rolePermissions into the running emulator: seed --school 12 --roles admin=4,teacher=7
# Runs as icueadmin-dev: Android/iOS apps take their project ID from google-services.json, so the
# emulators must answer on that project. All four services are emulated; outboxSend skips real
# FCM sends when running in the emulator, so nothing reaches the real project.
set -euo pipefail
cd "$(dirname "$0")/.."

DATA=.emulator-data
PROJECT=icueadmin-dev

case "${1:-}" in
  start)
    npm --prefix functions install --no-audit --no-fund --silent
    npm --prefix functions run build
    args=(--project "$PROJECT" --export-on-exit "$DATA")
    [ -d "$DATA" ] && args+=(--import "$DATA")
    exec firebase emulators:start "${args[@]}"
    ;;
  reset)
    rm -rf "$DATA"
    echo "Removed firebase/$DATA"
    ;;
  seed)
    shift
    if [[ " $* " != *" --school "* || " $* " != *" --roles "* ]]; then
      echo "Usage: melos run emulators:seed -- --school <OrganizationId> --roles admin=<RoleId>[,teacher=<RoleId>...]" >&2
      echo "  e.g. melos run emulators:seed -- --school 8 --roles admin=8   (OrganizationId and Roles[].Id from the login response)" >&2
      echo "  Role names: admin, principal, inventoryManager, storekeeper, procurement, librarian, teacher. Add --force to overwrite." >&2
      exit 1
    fi
    FIRESTORE_EMULATOR_HOST=127.0.0.1:8190 npm --prefix functions run seed -- --project "$PROJECT" "$@"
    ;;
  *)
    echo "Usage: $0 start|reset|seed" >&2
    exit 1
    ;;
esac
