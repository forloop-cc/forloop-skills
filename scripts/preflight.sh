#!/usr/bin/env bash
# preflight.sh — verify the ForLoop CLI environment for planning.
#
# Usage:
#   ./scripts/preflight.sh
#   source ./scripts/preflight.sh   # exports FORLOOP_READY / FORLOOP_JQ_AVAILABLE
#
# Exit codes: 0 = ready, 1 = CLI missing/uninstallable, 2 = not authenticated or auth state unusable
if [ -z "${BASH_VERSION:-}" ]; then
  echo "preflight: bash is required — run with bash, or source from bash (zsh is not supported)" >&2
  return 1 2>/dev/null || exit 1
fi

_pf_sourced=0
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  _pf_sourced=1
fi

_pf_main() {
  local _pf_auth_output _pf_version_output _pf_version_rc

  FORLOOP_READY=0
  FORLOOP_JQ_AVAILABLE=0
  export FORLOOP_READY FORLOOP_JQ_AVAILABLE

  echo "ForLoop preflight"

  if ! command -v forloop >/dev/null 2>&1; then
    echo "forloop: not found"
    if ! command -v node >/dev/null 2>&1; then
      echo "node: not found — install Node.js from https://nodejs.org"
      return 1
    fi
    if ! command -v npm >/dev/null 2>&1; then
      echo "npm: not found — reinstall Node.js (npm is bundled)"
      return 1
    fi
    echo "Installing @forloop-cc/forloop-cli ..."
    if ! npm install -g @forloop-cc/forloop-cli; then
      echo "Install failed — check network access and npm registry: npm config get registry"
      return 1
    fi
    hash -r 2>/dev/null || true
    if ! command -v forloop >/dev/null 2>&1; then
      echo "forloop: install could not be verified (not found on PATH)"
      echo "  Check: npm config get prefix"
      echo "  Ensure its bin directory is on PATH (for example <prefix>/bin)."
      echo "  If npm reported EACCES, fix the prefix permissions (e.g. npm config set prefix ~/.npm-global), then re-run."
      return 1
    fi
  fi

  _pf_version_output="$(forloop --version 2>&1)"
  _pf_version_rc=$?
  if [ "$_pf_version_rc" -ne 0 ] || [ -z "$_pf_version_output" ]; then
    echo "forloop: install could not be verified (--version failed)"
    echo "  Check: npm config get prefix"
    echo "  Ensure its bin directory is on PATH (for example <prefix>/bin)."
    echo "  If npm reported EACCES, fix the prefix permissions (e.g. npm config set prefix ~/.npm-global), then re-run."
    return 1
  fi
  printf 'forloop: %s\n' "$_pf_version_output"

  if command -v jq >/dev/null 2>&1; then
    FORLOOP_JQ_AVAILABLE=1
    echo "jq: found"
  else
    echo "jq: not found (recommended; install with: brew install jq | apt-get install jq)"
  fi

  _pf_auth_output="$(forloop auth status 2>&1 || true)"
  case "$_pf_auth_output" in
    *"Not authenticated"*)
      echo "auth: not authenticated"
      echo ""
      echo "Authenticate:"
      echo "  1. Create a token: https://forloop.cc/profile?tab=api-tokens"
      echo "     Scopes: sprint:read, sprint:write, story:read, story:write, agent:query, organization:read, profile:read"
      echo "  2. Run: forloop auth login --api-key floop_xxxxx"
      return 2
      ;;
    *"Format: valid"*)
      echo "auth: token format valid"
      echo "Preflight passed."
      FORLOOP_READY=1
      export FORLOOP_READY FORLOOP_JQ_AVAILABLE
      return 0
      ;;
    *)
      echo "auth: state unrecognized/invalid — re-run: forloop auth login --api-key floop_xxxxx"
      return 2
      ;;
  esac
}

if [ "$_pf_sourced" -eq 1 ]; then
  _pf_status=0
  _pf_main || _pf_status=$?
  unset -f _pf_main
  unset _pf_sourced
  case "$_pf_status" in
    0) unset _pf_status; return 0 ;;
    1) unset _pf_status; return 1 ;;
    *) unset _pf_status; return 2 ;;
  esac
fi

set -uo pipefail
_pf_main
exit $?
