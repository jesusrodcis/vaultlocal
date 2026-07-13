# fix-encoding.ps1
# Repairs UTF-8-read-as-Windows-1252 double-encoded mojibake in index.html.
# Reverses: text was UTF-8 but got interpreted as Windows-1252, producing
# sequences like "â‚¬" (was €), "â€”" (was —), "ðŸ”’" (was 🔒).

$ErrorActionPreference = 'Stop'
$file = Join-Path $PWD 'index.html'

Write-Host "=== index.html encoding repair ===" -ForegroundColor Cyan

# 1) Backup (do not overwrite an existing backup)
$backup = "$file.mojibake-backup"
if (Test-Path $backup) {
    $backup = "$file.mojibake-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
}
Copy-Item $file $backup
Write-Host "  Backup written: $backup"

# 2) Read current bytes, decode as UTF-8 to get the (mojibake) text
$bytes = [System.IO.File]::ReadAllBytes($file)
$text  = [System.Text.Encoding]::UTF8.GetString($bytes)

# Pre-repair stats
$before_euro = ([regex]::Matches($text,'â‚¬')).Count
$before_dbl  = ([regex]::Matches($text,'â€')).Count
Write-Host "  Before  -> 'â‚¬': $before_euro   'â€': $before_dbl"

# 3) Reverse the bad layer:
#    The mojibake chars are the Windows-1252 interpretation of the original
#    UTF-8 bytes. So: encode current text as Windows-1252 to recover those
#    original bytes, then decode them as UTF-8 to restore real characters.
$win1252 = [System.Text.Encoding]::GetEncoding(1252)
$recoveredBytes = $win1252.GetBytes($text)
$fixed = [System.Text.Encoding]::UTF8.GetString($recoveredBytes)

# Post-repair stats
$after_euro = ([regex]::Matches($fixed,'â‚¬')).Count
$after_dbl  = ([regex]::Matches($fixed,'â€')).Count
$has_euro   = $fixed.Contains([char]0x20AC)   # €
$has_dash   = $fixed.Contains([char]0x2014)   # —

# 4) Write clean UTF-8 WITHOUT BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $fixed, $utf8NoBom)

# 5) Verify on-disk result
$nb = [System.IO.File]::ReadAllBytes($file)
Write-Host ""
Write-Host "=== VERIFICATION ===" -ForegroundColor Cyan
Write-Host ("  Remaining 'â‚¬' (want 0): {0}" -f $after_euro)
Write-Host ("  Remaining 'â€' (want 0): {0}" -f $after_dbl)
Write-Host ("  Contains '€'  (want True): {0}" -f $has_euro)
Write-Host ("  Contains '—'  (want True): {0}" -f $has_dash)
Write-Host ("  First 3 bytes (want 60 33 68): {0} {1} {2}" -f $nb[0], $nb[1], $nb[2])
Write-Host ("  File size bytes: {0}" -f $nb.Length)
Write-Host ""
if ($after_euro -eq 0 -and $after_dbl -eq 0 -and $has_euro) {
    Write-Host "  RESULT: CLEAN - safe to deploy." -ForegroundColor Green
} else {
    Write-Host "  RESULT: NOT fully clean - do NOT deploy, report the summary." -ForegroundColor Yellow
    Write-Host "  (Restore from backup if needed: Copy-Item '$backup' '$file' -Force)"
}
