# ToiUuMedia.ps1 - Nen anh/video goc thanh ban nhe de dua len web.
#
# CACH DUNG:
#   1. Bo anh / video GOC (ten gi cung duoc) vao thu muc  Nguon\
#   2. Bam dup  ToiUuMedia.bat
#   3. Ban nhe tu dong vao thu muc anh voi ten  img_<so tiep theo>_<id>.<duoi>
#      (id lay tu ten file goc, de sau nay doi thu tu van biet file nao la file nao)
#   4. danhsach.json duoc cap nhat tu dong. Sau do chi viec  git add / commit / push.
#
# Thu muc Nguon\ KHONG bi day len GitHub. File da xu ly se khong bi xu ly lai.

param(
  [double]$VideoSeconds = 5.5,   # cat moi video con bay nhieu giay
  [int]$MaxPhotoSide   = 1920,   # canh dai nhat cua anh (px)
  [int]$MaxVideoSide   = 1280,   # canh dai nhat cua video (px)
  [int]$PhotoQuality   = 4,      # 2 (net nhat) .. 8 (nhe nhat)
  [int]$VideoCrf       = 26      # 18 (net) .. 30 (nhe)
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- tim ffmpeg ---
$ff = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ff) {
  $ff = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ff) { Write-Host "Khong tim thay ffmpeg. Cai bang: winget install Gyan.FFmpeg" -ForegroundColor Red; exit 1 }

# --- thu muc ---
$root = $PSScriptRoot
$out  = Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -match '^.nh$' } | Select-Object -First 1
if (-not $out) { Write-Host "Khong thay thu muc anh (Anh)." -ForegroundColor Red; exit 1 }
$src = Join-Path $root 'Nguon'
if (-not (Test-Path $src)) { New-Item -ItemType Directory -Path $src | Out-Null }
$log = Join-Path $src '_da_xu_ly.csv'
if (-not (Test-Path $log)) { '' | Set-Content $log -Encoding UTF8 }
$done = @{}
Get-Content $log -Encoding UTF8 | Where-Object { $_ } | ForEach-Object { $p = $_ -split '\|'; $done["$($p[0])|$($p[1])"] = $p[2] }

$imgExt = '.jpg','.jpeg','.png','.webp','.heic','.jfif','.bmp','.gif'
$vidExt = '.mp4','.mov','.m4v','.webm','.avi','.mkv'

# --- so thu tu tiep theo ---
function NextNumber {
  $m = Get-ChildItem $out.FullName -File | ForEach-Object { if ($_.Name -match '^img_(\d+)') { [int]$Matches[1] } } | Measure-Object -Maximum
  if ($m.Maximum) { return [int]$m.Maximum + 1 } else { return 1 }
}
function MakeId([string]$name, [string]$ext) {
  $b = [System.IO.Path]::GetFileNameWithoutExtension($name).ToLower() -replace '[^a-z0-9]', ''
  if ($b.Length -gt 12) { $b = $b.Substring($b.Length - 12) }   # lay phan duoi (thuong la phan phan biet)
  if (-not $b) { $b = 'x' }
  return $b
}

$files = Get-ChildItem $src -File | Where-Object { $_.Name -notlike '_*' } | Sort-Object Name
$count = 0; $skipped = 0; $before = 0; $after = 0
foreach ($f in $files) {
  $key = "$($f.Name)|$($f.Length)"
  if ($done.ContainsKey($key)) { $skipped++; continue }
  $ext = $f.Extension.ToLower()
  $isImg = $imgExt -contains $ext; $isVid = $vidExt -contains $ext
  if (-not ($isImg -or $isVid)) { Write-Host "Bo qua (khong ho tro): $($f.Name)" -ForegroundColor Yellow; continue }

  $n  = NextNumber
  $id = MakeId $f.Name $ext
  if ($isImg) {
    $name = "img_${n}_$id.jpg"
    $vf = "scale='min($MaxPhotoSide,iw)':'min($MaxPhotoSide,ih)':force_original_aspect_ratio=decrease"
    $args = @('-loglevel','error','-y','-i',$f.FullName,'-vf',$vf,'-q:v',"$PhotoQuality",'-frames:v','1',(Join-Path $out.FullName $name))
  } else {
    $name = "img_${n}_$id.mp4"
    $vf = "scale='min($MaxVideoSide,iw)':-2"
    $args = @('-loglevel','error','-y','-i',$f.FullName,'-t',"$VideoSeconds",'-vf',$vf,'-c:v','libx264','-crf',"$VideoCrf",'-preset','medium','-pix_fmt','yuv420p','-an','-movflags','+faststart',(Join-Path $out.FullName $name))
  }
  Write-Host ("[{0}] {1}  ->  {2}" -f $n, $f.Name, $name)
  & $ff @args
  if ($LASTEXITCODE -ne 0) { Write-Host "  LOI khi nen file nay, bo qua." -ForegroundColor Red; continue }
  $o = Get-Item (Join-Path $out.FullName $name)
  $before += $f.Length; $after += $o.Length; $count++
  Add-Content $log "$($f.Name)|$($f.Length)|$name" -Encoding UTF8
}

Write-Host ""
Write-Host ("Xong: {0} file moi, {1} file da xu ly truoc do (bo qua)." -f $count, $skipped) -ForegroundColor Green
if ($count -gt 0) { Write-Host ("Dung luong: {0:N1} MB  ->  {1:N1} MB" -f ($before/1MB), ($after/1MB)) -ForegroundColor Green }

# --- cap nhat danhsach.json ---
& (Join-Path $root 'CapNhatDanhSach.ps1')
