$path = 'C:\Users\Made by Felipe\Documents\Fleshwoods\scenes\world.tscn'
$content = [System.IO.File]::ReadAllText($path)

# Remove BOM if present
if ($content.StartsWith([char]0xFEFF)) {
    $content = $content.Substring(1)
    Write-Host "BOM removido"
}

# Fix position and remove scale for OutsideDoor
$pattern = '(\[node name="OutsideDoor" type="Area2D" parent="\." unique_id=427238742\])\r?\n(position = Vector2\([^)]+\))\r?\nscale = Vector2\([^)]+\)'
$replacement = '$1' + "`r`n" + 'position = Vector2(400, 336)'

if ($content -match $pattern) {
    $content = $content -replace $pattern, $replacement
    Write-Host "Scale removido, position corrigido"
} else {
    Write-Host "Pattern de scale nao encontrado (pode ja estar correto)"
}

# Save WITHOUT BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
Write-Host "Salvo sem BOM"

# Verify first bytes
$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Host ("Primeiros bytes: " + $bytes[0] + " " + $bytes[1] + " " + $bytes[2] + " (esperado: 91 103 100 = '[gd')")
