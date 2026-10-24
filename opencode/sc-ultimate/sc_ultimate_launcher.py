#!/usr/bin/env python3
"""Wrapper conservador: no cambia la configuración global de SC ni guarda claves."""
import json, os, pathlib, re, subprocess, sys, tempfile, atexit

BASE = pathlib.Path(os.environ.get('XDG_CONFIG_HOME', str(pathlib.Path.home()/'.config'))) / 'opencode'
KIT = BASE/'sc-ultimate'

def jsonc_parse(s):
    # strip // and /* ... */ only outside string literals; preserves URLs inside strings
    out=[]; i=0; quoted=False; escape=False
    while i<len(s):
        c=s[i]
        if quoted:
            out.append(c)
            if escape: escape=False
            elif c=='\\': escape=True
            elif c=='"': quoted=False
            i+=1; continue
        if c=='"': quoted=True; out.append(c); i+=1; continue
        if s.startswith('//',i):
            while i<len(s) and s[i]!='\n': i+=1
            continue
        if s.startswith('/*',i):
            j=s.find('*/',i+2)
            if j<0: raise ValueError('Comentario JSONC sin cierre')
            i=j+2; continue
        out.append(c); i+=1
    s=''.join(out)
    # strip commas preceding } or ] outside strings
    out=[]; i=0; quoted=False; esc=False
    while i<len(s):
        c=s[i]
        if quoted:
            out.append(c)
            if esc: esc=False
            elif c=='\\': esc=True
            elif c=='"': quoted=False
            i+=1; continue
        if c=='"': quoted=True; out.append(c); i+=1; continue
        if c==',':
            j=i+1
            while j<len(s) and s[j].isspace():j+=1
            if j<len(s) and s[j] in '}]':i+=1;continue
        out.append(c);i+=1
    return json.loads(''.join(out))

def root_mcp():
    merged={}
    for fp in (BASE/'opencode.json',BASE/'opencode.jsonc'):
        if fp.exists():
            try:
                data=jsonc_parse(fp.read_text())
                merged.update(data.get('mcp',{}))
            except Exception as exc:
                print(f'AVISO: no puedo inspeccionar MCP en {fp}: {exc}; no desactivo servidores desconocidos.',file=sys.stderr)
    return merged

def main():
    argv=sys.argv[1:]; selected=[]; show=False; extras=[]
    for arg in argv:
        if arg.startswith('--mcp='):
            selected += [x for x in arg.split('=',1)[1].split(',') if x]
        elif arg=='--show-mcp':show=True
        else:extras.append(arg)
    servers=root_mcp()
    if show:
        print('Servidores MCP existentes en config global:')
        for k,v in servers.items():print(f'  {k} (enabled={v.get("enabled",True) if isinstance(v,dict) else "?"})')
        if not servers:print('  Ninguno encontrado (o definido solo por proyecto/otro archivo).')
        return 0
    names=set(servers)
    if selected and 'all' not in selected:
        unknown=set(selected)-names
        if unknown:
            print('ERROR: MCP desconocido en config global:',', '.join(sorted(unknown)),file=sys.stderr)
            print('Consulta sc-ultimate --show-mcp; configura el MCP en SC primero.',file=sys.stderr)
            return 2
    cfg=json.loads((KIT/'overlay.json').read_text())
    # preserve preexisting original project MCP by using only global names; project config overrides custom overlay.
    if servers:
        cfg['mcp']={name:{'enabled': bool('all' in selected or name in selected)} for name in servers}
    # generated beside overlay so relative prompt paths resolve.
    fd,path=tempfile.mkstemp(prefix='.runtime-',suffix='.json',dir=str(KIT),text=True)
    os.fchmod(fd,0o600)
    try:
        with os.fdopen(fd,'w') as f:json.dump(cfg,f,ensure_ascii=False,indent=2)
        env=os.environ.copy()
        env['OPENCODE_CONFIG']=path
        # A project configuration can still override this; explain rather than pretend absolute protection.
        if os.environ.get('OPENCODE_CONFIG_CONTENT'):
            print('AVISO: OPENCODE_CONFIG_CONTENT puede prevalecer sobre el kit.',file=sys.stderr)
        try:return subprocess.call(['opencode',*extras],env=env)
        except FileNotFoundError:
            print('ERROR: opencode no está instalado o no está en PATH.',file=sys.stderr)
            return 127
    finally:
        try:os.unlink(path)
        except FileNotFoundError:pass

if __name__=='__main__':sys.exit(main())

