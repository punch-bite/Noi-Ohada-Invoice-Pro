# Nettoyer les caracteres speciaux et reparer le fichier index.html
$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"
$content = Get-Content -Path $path -Raw

# Nettoyer les sequences incorrectes
$content = $content -replace '<script src="register-sw.js"></script>`n`n', ''
$content = $content -replace '`n`n', "`n"

# Supprimer toutes les occurrences de register-sw.js qui sont incorrectes
$content = $content -replace '(</html>)(\s*<script src="register-sw.js"></script>)', '$1'

# Ajouter le script correctement avant </body>
$content = $content -replace '(</body>)', "`n`n  <script src=`"register-sw.js`"`></script>`n$1"

Set-Content -Path $path -Value $content -Force -Encoding UTF8
Write-Host "Fichier index.html reparu."
