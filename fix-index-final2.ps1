# Nettoyer et reparer le fichier index.html
$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"
$content = Get-Content -Path $path -Raw

# Supprimer toutes les occurrences incorrectes de register-sw
$content = $content -replace '(<script src="register-sw.js"></script>)' , ''

# Re-ajouter le script correctement avant </body>
$content = $content -replace '(</body>)',
'
 
  <script src="register-sw.js"></script>
$1'

Set-Content -Path $path -Value $content -Force -Encoding UTF8
Write-Host "Fichier reparu."
