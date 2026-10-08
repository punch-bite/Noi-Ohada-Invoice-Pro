# Script: fix-index-step1.ps1
# Ajoute le script register-sw.js correctement avant </body>

$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"
$content = Get-Content -Path $path -Raw

# Trouver la position de </body> et l'inserer avant
$pos = $content.IndexOf("</body>")
if ($pos -ge 0) {
    $before = $content.Substring(0, $pos)
    $after = $content.Substring($pos)
    
    # Ajouter le script avant </body>
    # Ajouter le script avant </body>
    $scriptTag = "<script src=`"register-sw.js`"`></script>"
    $content = $before + "`n`n  " + $scriptTag + "`n" + $after
    # Ajouter le script avant </body>
    $content = $before + "`n`n  <script src="register-sw.js"></script>`n$after
    $content = $before + "`n`n  <script src=`"register-sw.js`"`></script>`n$after
}

Set-Content -Path $path -Value $content -Force -Encoding UTF8
Write-Host "Fichier mis a jour."
