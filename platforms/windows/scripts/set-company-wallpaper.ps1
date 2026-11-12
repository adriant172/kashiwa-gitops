# Set the company desktop wallpaper for every user on this Windows PC.
#
# Works without Windows MDM: Fleet runs this through fleetd as SYSTEM.
# It applies the "Desktop Wallpaper" user policy
# (HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System), which works
# on Windows Pro, Enterprise, and Education. The policy also stops users
# from changing the wallpaper. It takes effect the next time each user signs in.
#
# Steps:
#   1. Copy or download the image to C:\ProgramData\KashiwaOakWorks\Wallpaper.
#   2. Set the policy in every existing user profile, loading hives that
#      aren't already loaded.
#   3. Set it in the Default user profile so new users get it too.
#
# Safe to re-run: it overwrites the same file and registry values each time.

# TODO: set the wallpaper location before merging. Use an http(s) URL to a
# .jpg/.jpeg/.png, or a local or UNC path the SYSTEM account can read.
$WallpaperSource = ""

# 0 = Center, 1 = Tile, 2 = Stretch, 3 = Fit, 4 = Fill, 5 = Span
$WallpaperStyle = "4"

$ErrorActionPreference = "Stop"
$TargetDir = "C:\ProgramData\KashiwaOakWorks\Wallpaper"
$PolicySubkey = "Software\Microsoft\Windows\CurrentVersion\Policies\System"

if ([string]::IsNullOrWhiteSpace($WallpaperSource)) {
    Write-Output "No wallpaper location set. Edit `$WallpaperSource in this script."
    exit 1
}

# --- 1. Put the image in a fixed local location ----------------------------
$ext = [System.IO.Path]::GetExtension(($WallpaperSource -split '\?')[0]).ToLower()
if ($ext -notin @(".jpg", ".jpeg", ".png")) {
    Write-Output "Unsupported image type '$ext'. Use a .jpg, .jpeg, or .png."
    exit 1
}

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
# Remove an older image with a different extension so the policy check
# doesn't pass on a stale file.
Get-ChildItem -Path $TargetDir -Filter "wallpaper.*" -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ne $ext } | Remove-Item -Force
$WallpaperPath = Join-Path $TargetDir "wallpaper$ext"

try {
    if ($WallpaperSource -match '^https?://') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $WallpaperSource -OutFile $WallpaperPath -UseBasicParsing
    } else {
        Copy-Item -Path $WallpaperSource -Destination $WallpaperPath -Force
    }
} catch {
    Write-Output "Couldn't get the wallpaper from '$WallpaperSource': $($_.Exception.Message)"
    exit 1
}
Write-Output "Wallpaper saved to $WallpaperPath"

# --- 2 & 3. Apply the policy to each user hive ------------------------------
function Set-WallpaperPolicy([string]$HiveRoot) {
    $key = "Registry::$HiveRoot\$PolicySubkey"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name "Wallpaper" -Value $WallpaperPath -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $key -Name "WallpaperStyle" -Value $WallpaperStyle -PropertyType String -Force | Out-Null
}

$failures = 0
$profiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    Where-Object { $_.PSChildName -like "S-1-5-21-*" }

$targets = @()
foreach ($p in $profiles) {
    $targets += [pscustomobject]@{
        Name   = $p.PSChildName
        Loaded = Test-Path "Registry::HKEY_USERS\$($p.PSChildName)"
        Hive   = Join-Path (Get-ItemProperty $p.PSPath).ProfileImagePath "NTUSER.DAT"
    }
}
$targets += [pscustomobject]@{ Name = "Default"; Loaded = $false; Hive = "C:\Users\Default\NTUSER.DAT" }

foreach ($t in $targets) {
    try {
        if ($t.Loaded) {
            Set-WallpaperPolicy "HKEY_USERS\$($t.Name)"
        } else {
            if (-not (Test-Path $t.Hive)) { continue }
            $mount = "HKU\FleetWallpaper_$($t.Name)"
            & reg.exe load $mount $t.Hive | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "reg load failed ($LASTEXITCODE)" }
            try {
                Set-WallpaperPolicy "HKEY_USERS\FleetWallpaper_$($t.Name)"
            } finally {
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                & reg.exe unload $mount | Out-Null
            }
        }
        Write-Output "Applied wallpaper policy for $($t.Name)"
    } catch {
        Write-Output "Failed for $($t.Name): $($_.Exception.Message)"
        $failures++
    }
}

if ($failures -gt 0) { exit 1 }
Write-Output "Done. Users see the new wallpaper the next time they sign in."
exit 0
