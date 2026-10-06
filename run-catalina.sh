#!/usr/bin/env bash
set -euo pipefail

# Shared Tomcat/TomEE runner. :Run supplies the Maven root as working directory.
project_root="${NVIM_PROJECT_ROOT:-$PWD}"
server_home="${NVIM_SERVER_HOME:?Set NVIM_SERVER_HOME to the server installation}"
war_file="${NVIM_WAR_FILE:?Set NVIM_WAR_FILE, for example target/ROOT.war}"
context_path="${NVIM_CONTEXT_PATH:-/}"
http_port="${NVIM_HTTP_PORT:-8080}"
debug_port="${NVIM_DEBUG_PORT:-5005}"
case "${1:-}" in
    ''|--prepare-only) ;;
    *) printf '%s\n' 'Usage: bash run-catalina.sh [--prepare-only]' >&2; exit 1 ;;
esac
project_root="$(cd "$project_root" && pwd -P)"
server_home="$(cd "$server_home" && pwd -P)"
if [ ! -f "$project_root/pom.xml" ] || [ ! -x "$server_home/bin/catalina.sh" ]; then
    printf '%s\n' 'Expected a Maven project and executable server bin/catalina.sh.' >&2
    exit 1
fi
# Validate settings before changing files. Tomcat maps ROOT.war to / and
# foo#bar.war to /foo/bar, independently of the built WAR's original filename.
deployment_name="$(python3 - "$context_path" "$http_port" "$debug_port" <<'PY'
import re, sys
context, http, debug = sys.argv[1:]
for port in (http, debug):
    if not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise SystemExit('HTTP/debug ports must be integers from 1 to 65535')
if int(http) == int(debug):
    raise SystemExit('HTTP and debug ports must differ')
if context == '/':
    print('ROOT.war')
else:
    parts = context.removeprefix('/').split('/')
    if not context.startswith('/') or any(
        p in ('', '.', '..') or not re.fullmatch(r'[A-Za-z0-9_.-]+', p) for p in parts
    ):
        raise SystemExit('Context must be / or a path such as /my-app or /foo/bar')
    if len(parts) == 1 and parts[0] == 'ROOT':
        raise SystemExit('/ROOT conflicts with the root application naming convention')
    print('#'.join(parts) + '.war')
PY
)"
case "$war_file" in /*) ;; *) war_file="$project_root/$war_file" ;; esac
if [[ "$war_file" != *.war ]]; then
    printf '%s\n' 'NVIM_WAR_FILE must name a .war file.' >&2; exit 1
fi
# Separate each project/server combination, including server-version changes.
runtime_key="$(python3 - "$project_root" "$server_home" "$context_path" <<'PY'
import hashlib, sys
print(hashlib.sha256('\0'.join(sys.argv[1:]).encode()).hexdigest())
PY
)"
runtime_dir="${NVIM_SERVER_BASE:-${XDG_STATE_HOME:-$HOME/.local/state}/nvim/servers/$runtime_key}"
runtime_dir="$(python3 - "$runtime_dir" "$server_home" <<'PY'
from pathlib import Path
import sys
runtime, home = (Path(p).resolve() for p in sys.argv[1:])
if runtime == Path('/') or runtime == home or home in runtime.parents:
    raise SystemExit('Server base must be separate from the installation')
print(runtime)
PY
)"
umask 077
mkdir -p "$runtime_dir"/{bin,conf,logs,temp,webapps,work,lib}
exec 9>"$runtime_dir/.run.lock"
flock -n 9 || { printf '%s\n' 'This server base is already running.' >&2; exit 1; }
identity="$server_home|$project_root|$context_path"
if [ -f "$runtime_dir/.identity" ] && [ "$(cat "$runtime_dir/.identity")" != "$identity" ]; then
    printf '%s\n' 'Base belongs to different settings. Choose a new NVIM_SERVER_BASE.' >&2; exit 1
fi
if [ ! -f "$runtime_dir/conf/server.xml" ]; then
    cp -a "$server_home/conf/." "$runtime_dir/conf/"
    printf '%s\n' '# Environment comes from Neovim project settings.' > "$runtime_dir/bin/setenv.sh"
fi
printf '%s\n' "$identity" > "$runtime_dir/.identity"
python3 - "$runtime_dir/conf/server.xml" "$http_port" <<'PY'
import sys
import xml.etree.ElementTree as ET
path, http = sys.argv[1:]
tree = ET.parse(path)
root = tree.getroot()
root.set('port', '-1')  # :RunStop stops the foreground process group.
count = 0
for service in root.findall('Service'):
    for connector in list(service.findall('Connector')):
        protocol = connector.get('protocol', 'HTTP/1.1')
        if 'HTTP' in protocol.upper() and connector.get('SSLEnabled', '').lower() != 'true':
            connector.set('port', http)
            connector.set('address', '127.0.0.1')
            count += 1
        else:
            service.remove(connector)  # Local development uses just HTTP.
if count != 1:
    raise SystemExit('Expected exactly one non-TLS HTTP connector')
for host in root.iter('Host'):
    host.set('appBase', 'webapps')
tree.write(path, encoding='utf-8', xml_declaration=True)
PY
if [ "${1:-}" = --prepare-only ]; then
    printf '%s\n' "Prepared server base: $runtime_dir" "Deployment: $deployment_name"
    exit
fi
cd "$project_root"
if [ -x ./mvnw ]; then ./mvnw --batch-mode package; else mvn --batch-mode package; fi
if [ ! -f "$war_file" ]; then
    printf '%s\n' "WAR not found after packaging: $war_file" >&2; exit 1
fi
cp "$war_file" "$runtime_dir/webapps/$deployment_name"
export CATALINA_HOME="$server_home" CATALINA_BASE="$runtime_dir"
export JPDA_TRANSPORT=dt_socket JPDA_ADDRESS="127.0.0.1:$debug_port" JPDA_SUSPEND=n
printf '%s\n' "Starting http://127.0.0.1:$http_port$context_path with debugger port $debug_port"
exec "$server_home/bin/catalina.sh" jpda run
