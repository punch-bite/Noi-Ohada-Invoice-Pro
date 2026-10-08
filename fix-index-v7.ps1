# Script: fix-index-v7.ps1
# Recree le fichier index.html avec le script register-sw.js correctement place

$inPath = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html.original"
$outPath = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"

$content = Get-Content -Path $inPath -Raw

# Trouver la position de </body> et ajouter le script avant
$pos = $content.IndexOf("</body>")
if ($pos -ge 0) {
    $before = $content.Substring(0, $pos)
    $after = $content.Substring($pos)
    
    # Ajouter le script avant </body>
    $scriptTag = "<script src=`"register-sw.js`"`></script>"
    $content = $before + "`n`n  " + $scriptTag + "`n" + $after
}

Set-Content -Path $outPath -Value $content -Force -Encoding UTF8
Write-Host "Fichier recree"
