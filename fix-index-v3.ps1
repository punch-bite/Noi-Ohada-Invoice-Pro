# Script: fix-index-final.ps1
# Corrigee le fichier index.html - ajoute register-sw.js avant </body>

$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"
$content = Get-Content -Path $path -Raw

# Supprimer toutes les occurrences incorrectes
$content = $content -replace '(<script src="register-sw.js"></script>)', ''

# Ajouter le script correctement avant </body>
$content = $content -replace '(</body>)',
"`n`n  <script src=`"register-sw.js`"`></script>`n$1"

Set-Content -Path $path -Value $content -Force -Encoding UTF8
Write-Host "Fichier corrige"
