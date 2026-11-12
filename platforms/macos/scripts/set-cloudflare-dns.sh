#!/bin/sh
#
# Point every network service on this Mac at Cloudflare DNS
# (1.1.1.1 primary, 1.0.0.1 secondary), then flush the DNS cache.
#
# Runs as root via Fleet when the "macOS - DNS uses Cloudflare (1.1.1.1)"
# policy fails. Safe to re-run: it sets the same servers every time.
#
# Note: a VPN client that pushes its own resolvers can still take over
# while it's connected. This script doesn't fight VPN-scoped DNS.

DNS_SERVERS="1.1.1.1 1.0.0.1"
status=0
count=0

# `-listallnetworkservices` prints a header line first, and prefixes
# disabled services with "*". Set DNS on all of them (disabled ones keep
# the setting for when they're turned on).
services=$(/usr/sbin/networksetup -listallnetworkservices | /usr/bin/tail -n +2 | /usr/bin/sed 's/^\*//')

# Split on newlines only; service names contain spaces.
OLD_IFS=$IFS
IFS='
'
for service in $services; do
  [ -n "$service" ] || continue
  IFS=$OLD_IFS
  # shellcheck disable=SC2086 # DNS_SERVERS is intentionally word-split
  if /usr/sbin/networksetup -setdnsservers "$service" $DNS_SERVERS; then
    echo "Set DNS on \"$service\" to $DNS_SERVERS"
    count=$((count + 1))
  else
    echo "Failed to set DNS on \"$service\"" >&2
    status=1
  fi
  IFS='
'
done
IFS=$OLD_IFS

if [ "$count" -eq 0 ]; then
  echo "No network services found." >&2
  exit 1
fi

/usr/bin/dscacheutil -flushcache
/usr/bin/killall -HUP mDNSResponder 2>/dev/null || true
echo "Flushed DNS cache."

exit "$status"
