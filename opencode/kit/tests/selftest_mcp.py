#!/usr/bin/env python3
"""Servidor MCP mínimo para pruebas de sc-kit (stdio, sin dependencias)."""

import json
import sys


def reply(payload):
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        method = message.get("method")
        msg_id = message.get("id")
        if method == "initialize":
            reply({"jsonrpc": "2.0", "id": msg_id, "result": {
                "protocolVersion": "2025-06-18",
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "sc-kit-selftest", "version": "1.0.0"},
            }})
        elif method == "tools/list":
            reply({"jsonrpc": "2.0", "id": msg_id, "result": {"tools": [{
                "name": "echo",
                "description": "Devuelve el texto recibido. Solo para pruebas.",
                "inputSchema": {
                    "type": "object",
                    "properties": {"text": {"type": "string"}},
                    "required": ["text"],
                },
            }]}})
        elif method == "tools/call":
            text = (message.get("params", {}).get("arguments") or {}).get("text", "")
            reply({"jsonrpc": "2.0", "id": msg_id, "result": {
                "content": [{"type": "text", "text": f"echo: {text}"}],
                "isError": False,
            }})
        elif msg_id is not None:
            reply({"jsonrpc": "2.0", "id": msg_id, "error": {
                "code": -32601, "message": f"método no soportado: {method}"}})


if __name__ == "__main__":
    main()
