# Widget Studio app icon (M6): a 2x2 grid of widget shapes, white on black, one red accent.
# Same geometry as LogoMark.swift (unit square: margin 0.19, gap 0.0625, tile 0.28).
param([string]$out = "D:\widget\ios\WidgetStudio\Resources\Assets.xcassets\AppIcon.appiconset")
Add-Type -AssemblyName System.Drawing

function Draw($file, $bg, $fg, $accent, $transparent) {
  $s = 1024
  $bmp = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = "AntiAlias"; $g.PixelOffsetMode = "HighQuality"
  if ($transparent) { $g.Clear([System.Drawing.Color]::Transparent) } else { $g.Clear($bg) }
  $m = [int](0.19 * $s); $gap = [int](0.0625 * $s); $t = [int](0.28 * $s)
  $x1 = $m; $x2 = $m + $t + $gap; $y1 = $m; $y2 = $m + $t + $gap
  $white = New-Object System.Drawing.SolidBrush $fg
  $red = New-Object System.Drawing.SolidBrush $accent
  # Top-left: rounded square (a widget card) with a 3x3 dot-matrix inside, cut out.
  $r = [int]($t * 0.26)
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x1, $y1, 2*$r, 2*$r, 180, 90); $p.AddArc($x1+$t-2*$r, $y1, 2*$r, 2*$r, 270, 90)
  $p.AddArc($x1+$t-2*$r, $y1+$t-2*$r, 2*$r, 2*$r, 0, 90); $p.AddArc($x1, $y1+$t-2*$r, 2*$r, 2*$r, 90, 90); $p.CloseFigure()
  $g.FillPath($white, $p)
  $dot = [int]($t * 0.12); $step = [int]($t * 0.25)
  $holes = New-Object System.Drawing.SolidBrush $(if ($transparent) { [System.Drawing.Color]::Transparent } else { $bg })
  if ($transparent) { $g.CompositingMode = "SourceCopy" }
  for ($i = 0; $i -lt 3; $i++) { for ($j = 0; $j -lt 3; $j++) {
    $cx = $x1 + $t/2 + ($i - 1) * $step; $cy = $y1 + $t/2 + ($j - 1) * $step
    $g.FillEllipse($holes, $cx - $dot/2, $cy - $dot/2, $dot, $dot)
  } }
  $g.CompositingMode = "SourceOver"
  # Top-right: circle. Bottom-left: ring. Bottom-right: the red accent circle.
  $g.FillEllipse($white, $x2, $y1, $t, $t)
  $ring = New-Object System.Drawing.Pen $fg, ([single]($t * 0.16))
  $w = $t * 0.16
  $g.DrawEllipse($ring, $x1 + $w/2, $y2 + $w/2, $t - $w, $t - $w)
  $g.FillEllipse($red, $x2, $y2, $t, $t)
  $bmp.Save("$out\$file", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

$black = [System.Drawing.Color]::FromArgb(255, 14, 14, 14)
$white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$red = [System.Drawing.Color]::FromArgb(255, 226, 35, 26)
Draw "AppIcon-1024.png" $black $white $red $false
Draw "AppIcon-1024-dark.png" $black $white $red $false
# Tinted (iOS 18): grayscale shapes on transparent; the system applies the tint.
Draw "AppIcon-1024-tinted.png" $black ([System.Drawing.Color]::FromArgb(255, 235, 235, 235)) ([System.Drawing.Color]::FromArgb(255, 160, 160, 160)) $true
