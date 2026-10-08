# Script: fix-index-v4.ps1
# Ajoute le script register-sw.js avant </body> en utilisant une boucle

$path = "G:\futter_projets\noi_ohada_invoice_pro\web\index.html"
$lines = Get-Content -Path $path
$newLines = New-Object System.Collections.Generic.List[System.Object]

foreach ($line in $lines) {
    if ($line.Trim() -eq "</body>") {
        $newLines.Add("")
        $newLines.Add("  <script src=`"register-sw.js`"`></script>")
        $newLines.Add($line)
    } else {
        $newLines.Add($line)
    }
}

$newLines | Set-Content -Path $path -Force -Encoding UTF8
Write-Host "Fait"
