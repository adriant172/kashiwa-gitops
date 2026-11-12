#!/bin/sh
#
# Zoom post-install configuration (macOS)
#
# Fleet runs this as root right after Zoom is installed: during setup on
# new Macs, from self-service, or from any install automation.
#
# PLACEHOLDER: no Zoom settings are applied yet. Replace the owl below with
# our real configuration (for example, writing managed preferences to
# /Library/Preferences/us.zoom.config.plist). Exit non-zero on failure so
# Fleet marks the install as failed.

cat <<'OWL'
   ,_,
  (O,O)    Zoom landed!
  (   )    Configuration coming soon.
  -"-"-
OWL

exit 0
