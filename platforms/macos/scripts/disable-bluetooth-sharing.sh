#!/bin/sh
#
# Turn off Bluetooth Sharing (receiving files over Bluetooth) for every
# user on this Mac.
#
# Bluetooth Sharing is a per-user ByHost preference with no MDM payload,
# so it can't be enforced with a configuration profile. This applies the
# CIS macOS Benchmark remediation (`defaults -currentHost write
# com.apple.Bluetooth PrefKeyServicesEnabled -bool false`, run as each
# user) to every ByHost file the CIS policy checks.
#
# Runs as root via Fleet. Idempotent: safe to re-run on every policy failure.

status=0
found=0

for plist in /Users/*/Library/Preferences/ByHost/com.apple.Bluetooth.*.plist; do
  [ -f "$plist" ] || continue
  found=1
  owner=$(/usr/bin/stat -f '%Su' "$plist")
  domain=${plist%.plist}

  # Write as the file's owner so the change goes through that user's
  # preferences daemon (cfprefsd) and isn't overwritten from its cache.
  if /usr/bin/sudo -u "$owner" /usr/bin/defaults write "$domain" PrefKeyServicesEnabled -bool false; then
    echo "Disabled Bluetooth Sharing for $owner ($plist)"
  else
    echo "Failed to update $plist for $owner" >&2
    status=1
  fi
done

[ "$found" -eq 1 ] || echo "No Bluetooth ByHost preferences found; Bluetooth Sharing has never been turned on."

exit "$status"
