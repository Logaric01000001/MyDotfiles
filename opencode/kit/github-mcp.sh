#!/usr/bin/env bash
# GitHub MCP Server local vía Docker, autenticado con el token ya guardado por `gh`.
# El token no se escribe en la configuración ni se pasa por argumentos.
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub MCP: falta el CLI 'gh'." >&2
  exit 1
fi
TOKEN="$(gh auth token 2>/dev/null)" || {
  echo "GitHub MCP: ejecuta 'gh auth login' primero." >&2
  exit 1
}

export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"
export GITHUB_TOOLSETS="context,repos,issues,pull_requests,actions"

exec docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN \
  -e GITHUB_TOOLSETS \
  ghcr.io/github/github-mcp-server:latest
