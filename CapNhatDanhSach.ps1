# Quet thu muc anh/video va tao danhsach.json cho web.
# Dat ten: img_<so thu tu>.<duoi>  hoac  img_<so thu tu>_<id>.<duoi>   (vd img_30_c9890.mp4)
$dir = Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object { $_.Name -match '^.nh$' } | Select-Object -First 1
if (-not $dir) { Write-Host "Khong tim thay thu muc anh"; exit 1 }
$files = Get-ChildItem -Path $dir.FullName -File | Where-Object { $_.Name -match '^img_(\d+)(_[^.]+)?\.(jpg|jpeg|png|webp|gif|jfif|avif|mp4|webm|mov)$' } |
  Sort-Object { [int]([regex]::Match($_.Name,'^img_(\d+)').Groups[1].Value) }
$names = @($files | ForEach-Object { $_.Name })
$json = ConvertTo-Json -InputObject $names -Compress
[System.IO.File]::WriteAllText((Join-Path $dir.FullName 'danhsach.json'), $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("Da tao danhsach.json voi " + $names.Count + " file.")
