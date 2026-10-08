# Script: fix-index-final.ps1
# Nettoie et répare le fichier index.html

$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"
$content = Get-Content -Path $path -Raw

# Remplacer les séquences incorrectes ``\n`` par des vraies nouvelles lignes
$content = $content -replace '`n`n', "`n`n"

# Si le script est après </html>, le déplacer avant </body>
$content = $content -replace '(</html>)(\s*<script src="register-sw.js"></script>)', '$1'
$content = $content -replace '(<script src="flutter_bootstrap.js"[^>]*></script>)', '$1`n`n  <script src="register-sw.js"></script>'

Set-Content -Path $path -Value $content -Force -Encoding UTF8
Write-Host "Fichier index.html nettoyé et réparer."
