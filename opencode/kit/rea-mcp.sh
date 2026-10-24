#!/usr/bin/env bash
# REA MCP con proveedores locales instalados en ~/opt (sin root).
set -euo pipefail

GHIDRA_DIR="$(ls -d "$HOME"/opt/ghidra_* 2>/dev/null | head -1 || true)"
JDK_DIR="$(ls -d "$HOME"/opt/jdk-21* 2>/dev/null | head -1 || true)"

[[ -n "$GHIDRA_DIR" ]] && export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
[[ -n "$JDK_DIR" ]] && export JAVA_HOME="$JDK_DIR"
JADX_JAR="$HOME/.local/share/rea/android/jadx-headless-mcp-0.7.1-all.jar"
[[ -f "$JADX_JAR" ]] && export REA_JADX_MCP_JAR="$JADX_JAR"
export PATH="$HOME/opt/jadx/bin:$HOME/opt/apktool:$HOME/opt/platform-tools:$PATH"

exec npx -y rea-agents@6.7.0 mcp
