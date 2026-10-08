#!/usr/bin/env bash
# ABOUTME: Task 9 probe (throwaway): can agent reach the network through local services after sandbox.sh close?
# ABOUTME: Run as root on a runner. Prints one line per attempt; a nip.io answer of 10.11.12.13 proves a query left the runner.
set -uo pipefail

# AS_AGENT is how to run a command as agent: sandbox.sh's way by default, or the prototype wrapper.
AS_AGENT=${AS_AGENT:-"sudo -u agent env -i HOME=/home/agent PATH=$PATH"}
nonce=$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')
name() { echo "p${nonce}$1-10-11-12-13.nip.io"; }

try() { # try <label> <command...>: run as agent, as the workflow does
  local label=$1; shift
  local out rc
  out=$($AS_AGENT timeout 25 "$@" 2>&1); rc=$?
  printf '### %s (exit %s)\n%s\n\n' "$label" "$rc" "$(printf '%s' "$out" | head -c 1500)"
}

phase=$1
echo "=== phase: $phase, nonce $nonce"
try "getent hosts" getent hosts "$(name a)"
try "resolvectl query" resolvectl query "$(name b)"
try "busctl resolve1 ResolveHostname" busctl call org.freedesktop.resolve1 /org/freedesktop/resolve1 org.freedesktop.resolve1.Manager ResolveHostname isit 0 "$(name c)" 0 0
try "varlink io.systemd.Resolve" varlinkctl call /run/systemd/resolve/io.systemd.Resolve io.systemd.Resolve.ResolveHostname "{\"name\":\"$(name d)\"}"
try "dig via 127.0.0.53" dig +time=3 +tries=1 "$(name e)"
try "curl https" curl -sS -m 10 -o /dev/null -w '%{http_code}' https://example.com
try "snap find" snap find hello
try "ping" ping -c1 -W3 1.1.1.1

if [ "$phase" = confined ]; then
  try "gateway stand-in at 10.199.0.1:8199" curl -sS -m 5 -o /dev/null -w '%{http_code}' http://10.199.0.1:8199/
  try "host loopback 127.0.0.1:8199" curl -sS -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8199/
  try "host on another port" curl -sS -m 5 -o /dev/null -w '%{http_code}' http://10.199.0.1:22/
  try "own loopback server" sh -c 'python3 -m http.server --bind 127.0.0.1 9999 >/dev/null 2>&1 & sleep 1; curl -sS -m 5 -o /dev/null -w "%{http_code}" http://127.0.0.1:9999/'
  try "routes" ip route
  try "sockets on disk agent sees" sh -c 'find / -xdev -type s 2>/dev/null; find /run /tmp -type s 2>/dev/null'
  try "id" id
fi
if [ "$phase" = closed ] || [ "$phase" = confined ]; then
  if [ "$phase" = closed ]; then
    echo "=== tools and kernel"
    uname -r
    for t in bwrap unshare setpriv systemd-run varlinkctl pkcon snap nscd; do printf '%s: %s\n' "$t" "$(command -v "$t" || echo missing)"; done
    systemctl --version | head -1
    sysctl kernel.apparmor_restrict_unprivileged_userns kernel.unprivileged_userns_clone 2>&1
  fi
  echo "=== system bus names agent can see"
  $AS_AGENT busctl list --no-pager --no-legend 2>&1 | awk '{print $1, $3, $5}' | grep -v '^:' | head -60
  echo "=== listening unix sockets, and whether agent can connect"
  ss -xlnpH | awk '{print $5, $NF}' | sort -u | while read -r addr proc; do
    r=$($AS_AGENT python3 -I -c '
import socket, sys
a = sys.argv[1]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(3)
try:
    s.connect("\0" + a[1:] if a.startswith("@") else a); print("CONNECTS")
except Exception as e:
    print("refused:", type(e).__name__)' "$addr" 2>&1)
    printf '%-70s %-10s %s\n' "$addr" "$r" "$proc"
  done
fi
