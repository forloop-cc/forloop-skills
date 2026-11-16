#!/usr/bin/env bash
# run.sh — build and start a fresh E2E container for forloop-skills.
#
# Usage:
#   ./run.sh                 # build image, start detached container, print exec hints
#   ./run.sh --run           # build, start, and execute the E2E suite immediately
#   ./run.sh --no-build      # reuse the existing image
#   ./run.sh --keep          # keep the container running after the suite exits
#
# Environment passed through to the container:
#   FORLOOP_E2E_TOKEN       login credential; read from ~/.config/forloop/tokens.json
#                           (field "default") or the host FORLOOP_E2E_TOKEN
#   FORLOOP_E2E_SPRINT_ID   optional disposable space id enabling the write test
#   FORLOOP_API_URL         optional API override
#   FORLOOP_ALLOW_DEV       optional dev-URL allow flag
#
# The token is passed as a container environment variable at run time and the
# in-container suite performs a real `forloop auth login --api-key` with it
# (the published CLI does not read tokens from the environment). It is never
# baked into the image or written to a file in this repository.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-forloop-skills-e2e:local}"
NAME="${NAME:-forloop-e2e}"

DO_BUILD=true
DO_RUN=false
DO_KEEP=false

for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=false ;;
    --run)      DO_RUN=true ;;
    --keep)     DO_KEEP=true ;;
    -h|--help)  sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# Resolve the token on the host without printing it.
TOKEN="${FORLOOP_E2E_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f "$HOME/.config/forloop/tokens.json" ]; then
  TOKEN="$(jq -r '.default // empty' "$HOME/.config/forloop/tokens.json" 2>/dev/null || true)"
fi
if [ -z "$TOKEN" ]; then
  echo "Warning: no ForLoop token found; auth/API stages will be skipped."
fi

if [ "$DO_BUILD" = true ]; then
  echo "Building $IMAGE ..."
  docker build -t "$IMAGE" "$DIR"
fi

docker rm -f "$NAME" >/dev/null 2>&1 || true

DOCKER_ENV=()
[ -n "$TOKEN" ] && DOCKER_ENV+=(-e "FORLOOP_E2E_TOKEN=$TOKEN")
[ -n "${FORLOOP_E2E_SPRINT_ID:-}" ] && DOCKER_ENV+=(-e "FORLOOP_E2E_SPRINT_ID=$FORLOOP_E2E_SPRINT_ID")
[ -n "${FORLOOP_API_URL:-}" ] && DOCKER_ENV+=(-e "FORLOOP_API_URL=$FORLOOP_API_URL")
[ -n "${FORLOOP_ALLOW_DEV:-}" ] && DOCKER_ENV+=(-e "FORLOOP_ALLOW_DEV=$FORLOOP_ALLOW_DEV")

echo "Starting $NAME ..."
docker run -d --name "$NAME" "${DOCKER_ENV[@]}" "$IMAGE" sleep infinity >/dev/null

echo ""
echo "Container running: $NAME"
echo "  Exec shell : docker exec -it $NAME bash"
echo "  Run suite  : docker exec $NAME bash /opt/e2e/e2e.sh"

if [ "$DO_RUN" = true ]; then
  echo ""
  docker exec "$NAME" bash /opt/e2e/e2e.sh
  STATUS=$?
  if [ "$DO_KEEP" = false ]; then
    echo ""
    echo "Stopping $NAME (use --keep to retain)."
    docker rm -f "$NAME" >/dev/null
  fi
  exit "$STATUS"
fi
