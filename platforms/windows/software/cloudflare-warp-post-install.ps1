# Cloudflare WARP post-install configuration (Windows)
#
# Fleet runs this as SYSTEM right after it installs Cloudflare WARP
# (Cloudflare One Client) on a Personal mobile devices host.
#
# PLACEHOLDER: no WARP settings are applied yet. Replace the fox below with
# our real configuration (for example, writing
# C:\ProgramData\Cloudflare\mdm.xml with the organization, auth, and
# service mode). Exit non-zero on failure so Fleet marks the install as failed.

Write-Output @'
   /\   /\
  //\\_//\\     ____
  \_     _/    /   /    WARP installed!
   / * * \    /^^^]     Configuration coming soon.
   \_\O/_/    [   ]
    /   \_    [   /
    \     \_  /  /
     [ [ /  \/ _/
    _[ [ \  /_/
'@

exit 0
