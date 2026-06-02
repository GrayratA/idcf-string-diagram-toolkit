param(
  [string]$Tag = 'r4w2'
)

$structRoot = Split-Path -Parent $PSScriptRoot
$rawDir = Join-Path $structRoot 'raw'
$processedDir = Join-Path $structRoot 'processed'

$juliaPath = Join-Path $rawDir ("struct_julia_{0}.txt" -f $Tag)
$rPath = Join-Path $rawDir ("struct_r_{0}.txt" -f $Tag)
$y0Path = Join-Path $rawDir ("struct_y0_{0}.txt" -f $Tag)

$juliaCsvPath = Join-Path $processedDir ("struct_julia_{0}.csv" -f $Tag)
$rCsvPath = Join-Path $processedDir ("struct_r_{0}.csv" -f $Tag)
$y0CsvPath = Join-Path $processedDir ("struct_y0_{0}.csv" -f $Tag)
$combinedCsvPath = Join-Path $processedDir ("struct_combined_{0}.csv" -f $Tag)
$combinedY0JuliaCsvPath = Join-Path $processedDir ("struct_y0_julia_{0}.csv" -f $Tag)
$combinedY0RCsvPath = Join-Path $processedDir ("struct_y0_r_{0}.csv" -f $Tag)
$combinedAllCsvPath = Join-Path $processedDir ("struct_all_{0}.csv" -f $Tag)

function Parse-Lines($path, $impl) {
  $rows = @()
  Get-Content $path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line.StartsWith("impl=$impl family=")) { return }
    $obj = [ordered]@{}
    foreach ($tok in ($line -split ' ')) {
      if ($tok -notmatch '=') { continue }
      $kv = $tok -split '=', 2
      $k = $kv[0]; $v = $kv[1]
      if ($v -match '^(true|false|TRUE|FALSE)$') { $obj[$k] = $v }
      elseif ($v -match '^[0-9]+$') { $obj[$k] = [int]$v }
      elseif ($v -match '^[0-9]+\.[0-9]+$') { $obj[$k] = [double]$v }
      else { $obj[$k] = $v }
    }
    $rows += [pscustomobject]$obj
  }
  return $rows
}

$j = Parse-Lines $juliaPath 'julia_struct'
$r = Parse-Lines $rPath 'r_struct'
$y0 = @()
if (Test-Path $y0Path) {
  $y0 = Parse-Lines $y0Path 'python_y0_struct'
}

$j | Export-Csv -NoTypeInformation -Path $juliaCsvPath
$r | Export-Csv -NoTypeInformation -Path $rCsvPath
if ($y0.Count -gt 0) {
  $y0 | Export-Csv -NoTypeInformation -Path $y0CsvPath
}

$indexR = @{}
foreach ($row in $r) {
  $indexR["$($row.family)|$($row.n)"] = $row
}

$combined = @()
foreach ($jr in $j) {
  $key = "$($jr.family)|$($jr.n)"
  if (-not $indexR.ContainsKey($key)) { continue }
  $rr = $indexR[$key]
  $combined += [pscustomobject][ordered]@{
    family = $jr.family
    n = $jr.n
    julia_total_ms = [double]$jr.warm_total_median_ms
    r_total_ms = [double]$rr.warm_total_median_ms
    speedup_total_r_over_julia = [math]::Round(([double]$rr.warm_total_median_ms / [double]$jr.warm_total_median_ms), 4)
    julia_setup_ms = [double]$jr.warm_setup_median_ms
    r_setup_ms = [double]$rr.warm_setup_median_ms
    speedup_setup_r_over_julia = [math]::Round(([double]$rr.warm_setup_median_ms / [double]$jr.warm_setup_median_ms), 4)
    julia_identify_ms = [double]$jr.warm_identify_median_ms
    r_identify_ms = [double]$rr.warm_identify_median_ms
    speedup_identify_r_over_julia = [math]::Round(([double]$rr.warm_identify_median_ms / [double]$jr.warm_identify_median_ms), 4)
    julia_build_ms = [double]$jr.warm_build_median_ms
    julia_simplify_ms = [double]$jr.warm_simplify_median_ms
    julia_step4_ms = [double]$jr.warm_step4_median_ms
    julia_step5_ms = [double]$jr.warm_step5_median_ms
  }
}

$combined | Sort-Object family, n | Export-Csv -NoTypeInformation -Path $combinedCsvPath

if ($y0.Count -gt 0) {
  $indexY0 = @{}
  foreach ($row in $y0) {
    $indexY0["$($row.family)|$($row.n)"] = $row
  }

  $combinedY0Julia = @()
  foreach ($jr in $j) {
    $key = "$($jr.family)|$($jr.n)"
    if (-not $indexY0.ContainsKey($key)) { continue }
    $yr = $indexY0[$key]
    $combinedY0Julia += [pscustomobject][ordered]@{
      family = $jr.family
      n = $jr.n
      julia_ok = $jr.ok
      y0_ok = $yr.ok
      julia_total_ms = [double]$jr.warm_total_median_ms
      y0_total_ms = [double]$yr.warm_total_median_ms
      speedup_y0_over_julia_total = [math]::Round(([double]$yr.warm_total_median_ms / [double]$jr.warm_total_median_ms), 4)
      julia_identify_ms = [double]$jr.warm_identify_median_ms
      y0_identify_ms = [double]$yr.warm_identify_median_ms
      speedup_y0_over_julia_identify = [math]::Round(([double]$yr.warm_identify_median_ms / [double]$jr.warm_identify_median_ms), 4)
    }
  }
  $combinedY0Julia | Sort-Object family, n | Export-Csv -NoTypeInformation -Path $combinedY0JuliaCsvPath

  $combinedY0R = @()
  foreach ($rr in $r) {
    $key = "$($rr.family)|$($rr.n)"
    if (-not $indexY0.ContainsKey($key)) { continue }
    $yr = $indexY0[$key]
    $combinedY0R += [pscustomobject][ordered]@{
      family = $rr.family
      n = $rr.n
      r_ok = $rr.ok
      y0_ok = $yr.ok
      r_total_ms = [double]$rr.warm_total_median_ms
      y0_total_ms = [double]$yr.warm_total_median_ms
      speedup_r_over_y0_total = [math]::Round(([double]$rr.warm_total_median_ms / [double]$yr.warm_total_median_ms), 4)
      r_identify_ms = [double]$rr.warm_identify_median_ms
      y0_identify_ms = [double]$yr.warm_identify_median_ms
      speedup_r_over_y0_identify = [math]::Round(([double]$rr.warm_identify_median_ms / [double]$yr.warm_identify_median_ms), 4)
    }
  }
  $combinedY0R | Sort-Object family, n | Export-Csv -NoTypeInformation -Path $combinedY0RCsvPath

  $combinedAll = @()
  foreach ($jr in $j) {
    $key = "$($jr.family)|$($jr.n)"
    if (-not $indexR.ContainsKey($key)) { continue }
    if (-not $indexY0.ContainsKey($key)) { continue }
    $rr = $indexR[$key]
    $yr = $indexY0[$key]
    $combinedAll += [pscustomobject][ordered]@{
      family = $jr.family
      n = $jr.n
      julia_ok = $jr.ok
      r_ok = $rr.ok
      y0_ok = $yr.ok
      julia_total_ms = [double]$jr.warm_total_median_ms
      r_total_ms = [double]$rr.warm_total_median_ms
      y0_total_ms = [double]$yr.warm_total_median_ms
      julia_build_ms = [double]$jr.warm_build_median_ms
      julia_simplify_ms = [double]$jr.warm_simplify_median_ms
      julia_step4_ms = [double]$jr.warm_step4_median_ms
      julia_step5_ms = [double]$jr.warm_step5_median_ms
      speedup_total_r_over_julia = [math]::Round(([double]$rr.warm_total_median_ms / [double]$jr.warm_total_median_ms), 4)
      speedup_total_y0_over_julia = [math]::Round(([double]$yr.warm_total_median_ms / [double]$jr.warm_total_median_ms), 4)
      speedup_total_r_over_y0 = [math]::Round(([double]$rr.warm_total_median_ms / [double]$yr.warm_total_median_ms), 4)
      julia_identify_ms = [double]$jr.warm_identify_median_ms
      r_identify_ms = [double]$rr.warm_identify_median_ms
      y0_identify_ms = [double]$yr.warm_identify_median_ms
      speedup_identify_r_over_julia = [math]::Round(([double]$rr.warm_identify_median_ms / [double]$jr.warm_identify_median_ms), 4)
      speedup_identify_y0_over_julia = [math]::Round(([double]$yr.warm_identify_median_ms / [double]$jr.warm_identify_median_ms), 4)
      speedup_identify_r_over_y0 = [math]::Round(([double]$rr.warm_identify_median_ms / [double]$yr.warm_identify_median_ms), 4)
    }
  }
  $combinedAll | Sort-Object family, n | Export-Csv -NoTypeInformation -Path $combinedAllCsvPath
}

Write-Output ("written={0}" -f $juliaCsvPath)
Write-Output ("written={0}" -f $rCsvPath)
Write-Output ("written={0}" -f $combinedCsvPath)
if ($y0.Count -gt 0) {
  Write-Output ("written={0}" -f $y0CsvPath)
  Write-Output ("written={0}" -f $combinedY0JuliaCsvPath)
  Write-Output ("written={0}" -f $combinedY0RCsvPath)
  Write-Output ("written={0}" -f $combinedAllCsvPath)
}
