# =====================================================================
#  deploy-frontend.ps1
#  Deploy VaultLocal (index.html) to the EXISTING private S3 bucket
#  fronted by CloudFront (OAC, HTTPS) in the PERSONAL AWS account.
#
#  This is the day-to-day redeploy script: it re-uploads the static
#  files and invalidates the CloudFront cache so changes go live
#  immediately. All infrastructure already exists (see CONFIG below).
#
#  ACCOUNT NOTE:
#    Frontend (S3 + CloudFront) AND backend (Lambda + API Gateway)
#    both live in the PERSONAL account (513270132750).
#    Always run with --profile personal -> baked in via $Profile below.
# =====================================================================

$ErrorActionPreference = "Stop"

# ---------------------- CONFIG (live, working values) ----------------------
$Region      = "us-east-1"
$Profile     = "personal"                              # personal account 513270132750
$BucketName  = "vaultlocal-app-pers"                   # private S3 bucket (personal)
$DistId      = "E1BZ2WFA80OARC"                         # CloudFront distribution (personal)
$DistDomain  = "d3ulkkxnjp1epm.cloudfront.net"          # https://d3ulkkxnjp1epm.cloudfront.net
$SrcDir      = "C:\Users\jesus\Documents\Development\vault"
# ---------------------------------------------------------------------------

Write-Host "=== VaultLocal Frontend Deploy (personal account) ===" -ForegroundColor Cyan
Write-Host ""

# Sanity check: confirm we're on the personal account
$AccountId = (aws sts get-caller-identity --profile $Profile --query Account --output text)
if ($AccountId -ne "513270132750") {
    Write-Host "  ABORT: profile '$Profile' resolved to account $AccountId, expected 513270132750." -ForegroundColor Red
    exit 1
}
Write-Host "  AWS Account: $AccountId (profile: $Profile)" -ForegroundColor Green

# ---------------------------------------------------------------
# 1. Upload static files to S3
# ---------------------------------------------------------------
Write-Host "  Uploading site files from $SrcDir (no-cache headers, dev mode) ..." -ForegroundColor Yellow
$NoCache = "no-cache, no-store, must-revalidate"
aws s3 cp "$SrcDir\index.html"    "s3://$BucketName/index.html"    --content-type "text/html; charset=utf-8"             --cache-control $NoCache --region $Region --profile $Profile | Out-Null
aws s3 cp "$SrcDir\manifest.json" "s3://$BucketName/manifest.json" --content-type "application/json; charset=utf-8"       --cache-control $NoCache --region $Region --profile $Profile 2>$null | Out-Null
aws s3 cp "$SrcDir\sw.js"         "s3://$BucketName/sw.js"         --content-type "application/javascript; charset=utf-8" --cache-control $NoCache --region $Region --profile $Profile 2>$null | Out-Null
aws s3 cp "$SrcDir\ai-tools.js"    "s3://$BucketName/ai-tools.js"    --content-type "application/javascript; charset=utf-8" --cache-control $NoCache --region $Region --profile $Profile | Out-Null
Write-Host "  Files uploaded with no-cache (index.html, manifest.json, sw.js, ai-tools.js)." -ForegroundColor Green

# ---------------------------------------------------------------
# 2. Invalidate CloudFront cache so changes go live immediately
# ---------------------------------------------------------------
Write-Host "  Invalidating CloudFront cache ..." -ForegroundColor Yellow
aws cloudfront create-invalidation --distribution-id $DistId --paths "/*" --profile $Profile | Out-Null
Write-Host "  Invalidation requested." -ForegroundColor Green

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  DEPLOY COMPLETE" -ForegroundColor Green
Write-Host "  Your app (HTTPS):  https://$DistDomain" -ForegroundColor Green
Write-Host "  Bucket (private):  $BucketName"
Write-Host "  Distribution ID:   $DistId"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Cache invalidation usually completes in under a minute." -ForegroundColor Yellow
Write-Host "  Hard-refresh the browser (Ctrl+Shift+R) to see changes." -ForegroundColor Yellow
