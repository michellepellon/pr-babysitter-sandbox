#!/usr/bin/env bash
# ABOUTME: Task 9 probe (throwaway): prototype of the proposed fix. Puts agent in its own network namespace
# ABOUTME: with private /run and /tmp, reaching the host only at 10.199.0.1:8199. Run as root: confine.sh install.
set -euo pipefail
ip netns add babysit
ip link add bs0 type veth peer name bs1 netns babysit
ip addr add 10.199.0.1/30 dev bs0
ip link set bs0 up
ip -n babysit addr add 10.199.0.2/30 dev bs1
ip -n babysit link set bs1 up
ip -n babysit link set lo up
ip netns exec babysit iptables -A OUTPUT -o lo -j ACCEPT
ip netns exec babysit iptables -A OUTPUT -d 10.199.0.1 -p tcp --dport 8199 -j ACCEPT
ip netns exec babysit iptables -A OUTPUT -j REJECT
ip netns exec babysit ip6tables -A OUTPUT -o lo -j ACCEPT
ip netns exec babysit ip6tables -A OUTPUT -j REJECT
cat >/usr/local/sbin/as-agent <<'WRAP'
#!/bin/sh
# Run "$@" as agent in the babysit network namespace, with /run and /tmp private.
# ip netns exec makes a new mount namespace with / as a slave, so these mounts stay inside.
exec ip netns exec babysit sh -c 'mount -t tmpfs -o mode=755 none /run && mount -t tmpfs -o mode=1777 none /tmp &&
  cd /home/agent && exec setpriv --reuid=agent --regid=agent --init-groups env -i HOME=/home/agent PATH="$0" "$@"' "$PATH" "$@"
WRAP
chmod 755 /usr/local/sbin/as-agent
