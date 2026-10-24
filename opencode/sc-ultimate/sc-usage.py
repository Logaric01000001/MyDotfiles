#!/usr/bin/env python3
"""Lee estado de clave OpenRouter sin enviar solicitudes al modelo. Requiere OPENROUTER_API_KEY en entorno."""
import os, json, urllib.request, urllib.error
key=os.environ.get('OPENROUTER_API_KEY')
if not key:
    print('Define OPENROUTER_API_KEY solo en esta sesión de terminal o consulta https://openrouter.ai/settings/keys')
    raise SystemExit(0)
req=urllib.request.Request('https://openrouter.ai/api/v1/key',headers={'Authorization': 'Bearer '+key,'Accept':'application/json'})
try:
    with urllib.request.urlopen(req,timeout=10) as r: data=json.load(r).get('data',{})
except (urllib.error.URLError,ValueError) as err:
    print('No se pudo consultar el límite de la clave:',type(err).__name__);raise SystemExit(1)
for k in ('limit','limit_remaining','usage','usage_daily','usage_weekly','usage_monthly'):
    if k in data:print(f'{k}: {data[k]}')
print('El saldo total de cuenta y límites por clave pueden diferir. Revisa OpenRouter Activity.')

