$data = [System.IO.File]::ReadAllText('C:\Users\Made by Felipe\Documents\Fleshwoods\scenes\world.tscn')
$matches2 = [regex]::Matches($data, 'tile_map_data = PackedByteArray\("([^"]+)"\)')
Write-Host ("Found " + $matches2.Count + " blocks")

$blockIdx = 0
foreach ($m2 in $matches2) {
    $bytes = [Convert]::FromBase64String($m2.Groups[1].Value)
    Write-Host ("Block " + $blockIdx + ": " + $bytes.Length + " bytes")

    # Try src==1 and src==2
    for ($srcCheck = 0; $srcCheck -le 2; $srcCheck++) {
        $townTiles = @()
        for ($j = 0; $j -lt $bytes.Length - 11; $j += 12) {
            $x = [BitConverter]::ToInt16($bytes, $j)
            $y = [BitConverter]::ToInt16($bytes, $j+2)
            $src = [BitConverter]::ToUInt16($bytes, $j+4)
            $ax = [BitConverter]::ToInt16($bytes, $j+6)
            $ay = [BitConverter]::ToInt16($bytes, $j+8)
            if ($src -eq $srcCheck) { $townTiles += ,[array]($x,$y,$ax,$ay) }
        }
        if ($townTiles.Count -gt 0) {
            $xs = $townTiles | ForEach-Object { $_[0] }
            $ys = $townTiles | ForEach-Object { $_[1] }
            $minX = ($xs | Measure-Object -Min).Minimum
            $maxX = ($xs | Measure-Object -Max).Maximum
            $minY = ($ys | Measure-Object -Min).Minimum
            $maxY = ($ys | Measure-Object -Max).Maximum
            Write-Host ("  src=" + $srcCheck + ": " + $townTiles.Count + " tiles | X:" + $minX + "-" + $maxX + " (px" + ($minX*16) + "-" + ($maxX*16+15) + ") Y:" + $minY + "-" + $maxY + " (px" + ($minY*16) + "-" + ($maxY*16+15) + ")")
            # Show first 5 tiles
            $first5 = $townTiles | Select-Object -First 5
            foreach ($t in $first5) {
                Write-Host ("    tile(" + $t[0] + "," + $t[1] + ") atlas(" + $t[2] + "," + $t[3] + ")")
            }
        }
    }
    $blockIdx++
}
