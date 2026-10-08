# Script: fix-index-sw.ps1
# Corrige la position du script register-sw.js dans index.html

$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"
$content = Get-Content -Path $path -Raw

# Supprimer le script qui est après </html>
$content = $content -replace '(</html>)(\s*<script src="register-sw.js"></script>)', '$1'

# Ajouter le script avant </body>
$content = $content -replace '(</body>)', '  <script src="register-sw.js"></script>`n`n$1'

Set-Content -Path $path -Value $content -Force -Encoding UTF8
Write-Host "index.html corrigé."
