# Script: fix-index-v5.ps1
# Recree le fichier index.html avec le script register-sw.js correctement place

$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html.bak"
$content = Get-Content -Path $path -Raw

# Ajouter le script register-sw.js avant </body>
$content = $content -replace '(</body>)',
"`n`n  <script src=`"register-sw.js`"`></script>`n$1"

Set-Content -Path "G:\futter_projets\noi_ohada_invoice_pro\web\index.html" -Value $content -Force -Encoding UTF8
Write-Host "Fichier recree"
