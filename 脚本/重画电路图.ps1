$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$finalDir = Join-Path $root '成图输出'
$outDir = Join-Path $root '成图输出\重制版'
$compressedDir = Join-Path $root '成图输出\压缩版'
$symbolDir1 = Join-Path $root '元件图\_refined'
$symbolDir2 = Join-Path $root '元件图\_symbols'
$symbolDir3 = Join-Path $root '元件图\_symbols2'

New-Item -ItemType Directory -Force $finalDir | Out-Null

$ktNoFull = [System.Drawing.Bitmap]::FromFile((Join-Path $symbolDir3 'kt_delay_no_trim.png'))
$script:KtDelayNoGraphic = $ktNoFull.Clone([System.Drawing.Rectangle]::new(0, 0, 42, 90), $ktNoFull.PixelFormat)
$ktNoFull.Dispose()

$ktNcFull = [System.Drawing.Bitmap]::FromFile((Join-Path $symbolDir3 'kt_delay_nc_trim.png'))
$script:KtDelayNcGraphic = $ktNcFull.Clone([System.Drawing.Rectangle]::new(0, 0, 30, 93), $ktNcFull.PixelFormat)
$ktNcFull.Dispose()

$frNcBase = [System.Drawing.Bitmap]::FromFile((Join-Path $symbolDir2 'fr_nc_trim.png'))
$script:FrNcVertical = New-Object System.Drawing.Bitmap $frNcBase
$script:FrNcVertical.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)
$frNcBase.Dispose()

function New-Canvas($width, $height) {
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::White)
    return @{
        Bitmap = $bmp
        Graphics = $g
    }
}

function Save-TrimmedPng($bitmap, [string]$path, [int]$margin = 12, [int]$threshold = 248) {
    $minX = $bitmap.Width
    $minY = $bitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $bitmap.Height; $y++) {
        for ($x = 0; $x -lt $bitmap.Width; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            if (($pixel.R -lt $threshold) -or ($pixel.G -lt $threshold) -or ($pixel.B -lt $threshold)) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -lt 0) {
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        return
    }

    $left = [Math]::Max(0, $minX - $margin)
    $top = [Math]::Max(0, $minY - $margin)
    $right = [Math]::Min($bitmap.Width - 1, $maxX + $margin)
    $bottom = [Math]::Min($bitmap.Height - 1, $maxY + $margin)
    $rect = [System.Drawing.Rectangle]::new($left, $top, $right - $left + 1, $bottom - $top + 1)
    $trimmed = $bitmap.Clone($rect, $bitmap.PixelFormat)
    $trimmed.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $trimmed.Dispose()
}

function New-Pen([float]$width = 3) {
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, $width)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $pen
}

function New-Font([float]$size, [bool]$bold = $false) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    return New-Object System.Drawing.Font('SimSun', $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Draw-Text($g, [string]$text, [float]$x, [float]$y, [float]$size = 24, [bool]$bold = $false, [string]$color = 'Black') {
    $font = New-Font $size $bold
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::$color)
    $g.DrawString($text, $font, $brush, $x, $y)
    $brush.Dispose()
    $font.Dispose()
}

function Draw-CenteredText($g, [string]$text, [float]$cx, [float]$y, [float]$size = 24, [bool]$bold = $false, [string]$color = 'Black') {
    $font = New-Font $size $bold
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::$color)
    $s = $g.MeasureString($text, $font)
    $g.DrawString($text, $font, $brush, $cx - ($s.Width / 2), $y)
    $brush.Dispose()
    $font.Dispose()
}

function Draw-RightText($g, [string]$text, [float]$rightX, [float]$y, [float]$size = 24, [bool]$bold = $false, [string]$color = 'Black') {
    $font = New-Font $size $bold
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::$color)
    $s = $g.MeasureString($text, $font)
    $g.DrawString($text, $font, $brush, $rightX - $s.Width, $y)
    $brush.Dispose()
    $font.Dispose()
}

function Draw-ImageCentered($g, $img, [float]$cx, [float]$cy, [float]$scale = 1.0) {
    $w = [int]([Math]::Round($img.Width * $scale))
    $h = [int]([Math]::Round($img.Height * $scale))
    $x = [int]([Math]::Round($cx - ($w / 2)))
    $y = [int]([Math]::Round($cy - ($h / 2)))
    $g.DrawImage($img, $x, $y, $w, $h)
}

function Draw-AnchoredImage($g, $img, [float]$anchorX, [float]$topY, [float]$targetHeight, [float]$imageAnchorX) {
    $scale = $targetHeight / $img.Height
    $destW = $img.Width * $scale
    $destX = $anchorX - ($imageAnchorX * $scale)
    $g.DrawImage($img, $destX, $topY, $destW, $targetHeight)
    return @{
        X = $destX
        Width = $destW
        Height = $targetHeight
        Scale = $scale
    }
}

function Draw-Terminal($g, [float]$x, [float]$y) {
    $pen = New-Pen 3
    $g.DrawEllipse($pen, $x - 7, $y - 7, 14, 14)
    $pen.Dispose()
}

function Draw-FuseH($g, [float]$x, [float]$y, [float]$length = 60, [string]$label = '') {
    $pen = New-Pen 3
    $g.DrawLine($pen, $x - 16, $y, $x, $y)
    $g.DrawRectangle($pen, $x, $y - 10, $length, 20)
    $g.DrawLine($pen, $x + $length, $y, $x + $length + 16, $y)
    if ($label) {
        Draw-Text $g $label ($x + 2) ($y - 42) 28 $true
    }
    $pen.Dispose()
}

function Draw-Coil($g, [float]$cx, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    $rectW = 90
    $rectH = 44
    $g.DrawLine($pen, $cx, $topY, $cx, $topY + 16)
    $g.DrawRectangle($pen, $cx - ($rectW / 2), $topY + 16, $rectW, $rectH)
    $g.DrawLine($pen, $cx, $topY + 16 + $rectH, $cx, $topY + 16 + $rectH + 22)
    Draw-CenteredText $g $label $cx ($topY + 22) 26 $true
    $pen.Dispose()
    return $topY + 16 + $rectH + 22
}

function Draw-TimerCoil($g, [float]$cx, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    $rectW = 42
    $rectH = 28
    $leadTop = 14
    $leadBottom = 20
    $parts = $label -split '\s+', 2
    $mainLabel = $parts[0]
    $timeLabel = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $g.DrawLine($pen, $cx, $topY, $cx, $topY + $leadTop)
    $g.DrawRectangle($pen, $cx - ($rectW / 2), $topY + $leadTop, $rectW, $rectH)
    $g.DrawLine($pen, $cx - 18, $topY + $leadTop + 2, $cx - 8, $topY + $leadTop + 24)
    $g.DrawLine($pen, $cx - 8, $topY + $leadTop + 2, $cx - 18, $topY + $leadTop + 24)
    $g.DrawLine($pen, $cx, $topY + $leadTop + $rectH, $cx, $topY + $leadTop + $rectH + $leadBottom)
    Draw-Text $g $mainLabel ($cx + 28) ($topY + 12) 20 $true
    if ($timeLabel) {
        Draw-Text $g $timeLabel ($cx + 28) ($topY + 38) 18 $false
    }
    $pen.Dispose()
    return $topY + $leadTop + $rectH + $leadBottom
}

function Draw-KMNC($g, [float]$cx, [float]$cy, [string]$label) {
    $pen = New-Pen 3
    $top = $cy - 48
    $bottom = $cy + 48
    $g.DrawLine($pen, $cx, $top, $cx, $cy - 14)
    $g.DrawLine($pen, $cx, $cy + 14, $cx, $bottom)
    $g.DrawLine($pen, $cx - 22, $cy - 8, $cx, $cy + 14)
    $g.DrawLine($pen, $cx + 20, $cy - 34, $cx + 20, $cy - 8)
    $g.DrawLine($pen, $cx, $cy - 8, $cx + 20, $cy - 8)
    $g.DrawLine($pen, $cx + 8, $cy - 16, $cx + 24, $cy - 28)
    Draw-CenteredText $g $label $cx ($top - 34) 24 $true
    $pen.Dispose()
}

function Draw-KMMain3($g, [float[]]$xs, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    foreach ($x in $xs) {
        $g.DrawLine($pen, $x, $topY, $x, $topY + 36)
        $g.DrawArc($pen, $x - 16, $topY + 28, 24, 18, 205, 150)
        $g.DrawLine($pen, $x - 18, $topY + 40, $x, $topY + 74)
        $g.DrawLine($pen, $x, $topY + 74, $x, $topY + 148)
    }
    Draw-Text $g $label ($xs[0] - 64) ($topY + 58) 28 $true
    $pen.Dispose()
    return $topY + 148
}

function Draw-FRBlock3($g, [float[]]$xs, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    $left = $xs[0] - 18
    $right = $xs[$xs.Length - 1] + 18
    $rectY = $topY + 18
    $rectH = 44
    foreach ($x in $xs) {
        $g.DrawLine($pen, $x, $topY, $x, $rectY)
    }
    $g.DrawRectangle($pen, $left, $rectY, $right - $left, $rectH)
    foreach ($x in $xs) {
        $g.DrawLine($pen, $x, $rectY, $x, $rectY + 8)
        $g.DrawLine($pen, $x, $rectY + 8, $x - 14, $rectY + 8)
        $g.DrawLine($pen, $x - 14, $rectY + 8, $x - 14, $rectY + 22)
        $g.DrawLine($pen, $x - 14, $rectY + 22, $x + 8, $rectY + 22)
        $g.DrawLine($pen, $x + 8, $rectY + 22, $x + 8, $rectY + 34)
        $g.DrawLine($pen, $x + 8, $rectY + 34, $x, $rectY + 34)
        $g.DrawLine($pen, $x, $rectY + 34, $x, $rectY + $rectH)
        $g.DrawLine($pen, $x, $rectY + $rectH, $x, $rectY + $rectH + 56)
    }
    Draw-Text $g $label ($right + 16) ($rectY + 6) 28 $true
    $pen.Dispose()
    return $rectY + $rectH + 56
}

function Draw-Motor($g, [float]$cx, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    $r = 54
    $cy = $topY + $r
    $g.DrawEllipse($pen, $cx - $r, $topY, $r * 2, $r * 2)
    Draw-CenteredText $g $label $cx ($cy - 26) 28 $true
    Draw-CenteredText $g '3~' $cx ($cy + 8) 22 $false
    $pen.Dispose()
}

function Draw-MotorWithTerminals($g, [float[]]$xs, [float]$wireTopY, [string]$label) {
    $pen = New-Pen 3
    $terminalLabelY = $wireTopY + 2
    $leadStartY = $wireTopY + 22
    $circleTop = $wireTopY + 42
    $r = 54
    $cx = $xs[1]
    $cy = $circleTop + $r

    Draw-CenteredText $g 'U' $xs[0] $terminalLabelY 18 $false
    Draw-CenteredText $g 'V' $xs[1] $terminalLabelY 18 $false
    Draw-CenteredText $g 'W' $xs[2] $terminalLabelY 18 $false

    foreach ($x in $xs) {
        $g.DrawLine($pen, $x, $wireTopY, $x, $leadStartY)
    }
    $g.DrawLine($pen, $xs[0], $leadStartY, $cx - 28, $circleTop + 8)
    $g.DrawLine($pen, $xs[1], $leadStartY, $cx, $circleTop)
    $g.DrawLine($pen, $xs[2], $leadStartY, $cx + 28, $circleTop + 8)
    $g.DrawEllipse($pen, $cx - $r, $circleTop, $r * 2, $r * 2)
    Draw-CenteredText $g $label $cx ($cy - 24) 28 $true
    Draw-CenteredText $g '3~' $cx ($cy + 10) 22 $false

    $pen.Dispose()
    return $circleTop + ($r * 2)
}

function Draw-QSFUGroup($g, [float[]]$xs, [float]$yTop) {
    $pen = New-Pen 3
    foreach ($x in $xs) {
        Draw-Terminal $g $x $yTop
        $g.DrawLine($pen, $x, $yTop + 8, $x, $yTop + 48)
        $g.DrawLine($pen, $x - 18, $yTop + 60, $x, $yTop + 92)
        $g.DrawLine($pen, $x, $yTop + 92, $x, $yTop + 120)
        $g.DrawRectangle($pen, $x - 10, $yTop + 120, 20, 48)
        $g.DrawLine($pen, $x, $yTop + 168, $x, $yTop + 214)
    }
    $g.DrawLine($pen, $xs[0] - 34, $yTop + 70, $xs[$xs.Length - 1] - 8, $yTop + 70)
    Draw-Text $g 'L1' ($xs[0] - 20) ($yTop - 48) 30 $true
    Draw-Text $g 'L2' ($xs[1] - 20) ($yTop - 48) 30 $true
    Draw-Text $g 'L3' ($xs[2] - 20) ($yTop - 48) 30 $true
    Draw-Text $g 'QS' ($xs[2] + 36) ($yTop + 62) 28 $true
    Draw-Text $g 'FU1' ($xs[2] + 22) ($yTop + 128) 28 $true
    $pen.Dispose()
    return $yTop + 214
}

function New-DashPen([float]$width = 2) {
    $pen = New-Pen $width
    $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    return $pen
}

function Draw-SBNO($g, [float]$x, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    $dash = New-DashPen 2
    Draw-RightText $g $label ($x - 22) ($topY + 18) 20 $true
    $g.DrawLine($pen, $x, $topY, $x, $topY + 30)
    $g.DrawLine($pen, $x, $topY + 82, $x, $topY + 126)
    $g.DrawLine($pen, $x - 18, $topY + 50, $x, $topY + 82)
    $g.DrawLine($pen, $x - 48, $topY + 54, $x - 36, $topY + 54)
    $g.DrawLine($pen, $x - 48, $topY + 54, $x - 48, $topY + 68)
    $g.DrawLine($pen, $x - 48, $topY + 68, $x - 36, $topY + 68)
    $g.DrawLine($dash, $x - 36, $topY + 61, $x - 14, $topY + 61)
    $pen.Dispose()
    $dash.Dispose()
    return $topY + 126
}

function Draw-SBNC($g, [float]$x, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    $dash = New-DashPen 2
    Draw-RightText $g $label ($x - 22) ($topY + 18) 20 $true
    $g.DrawLine($pen, $x, $topY, $x, $topY + 26)
    $g.DrawLine($pen, $x, $topY + 26, $x, $topY + 48)
    $g.DrawLine($pen, $x, $topY + 48, $x + 18, $topY + 48)
    $g.DrawLine($pen, $x - 18, $topY + 58, $x, $topY + 86)
    $g.DrawLine($pen, $x, $topY + 86, $x, $topY + 126)
    $g.DrawLine($pen, $x - 48, $topY + 54, $x - 36, $topY + 54)
    $g.DrawLine($pen, $x - 48, $topY + 54, $x - 48, $topY + 68)
    $g.DrawLine($pen, $x - 48, $topY + 68, $x - 36, $topY + 68)
    $g.DrawLine($dash, $x - 36, $topY + 61, $x - 14, $topY + 61)
    $pen.Dispose()
    $dash.Dispose()
    return $topY + 126
}

function Draw-KMNO($g, [float]$x, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    Draw-RightText $g $label ($x - 16) ($topY + 18) 20 $true
    $g.DrawLine($pen, $x, $topY, $x, $topY + 28)
    $g.DrawArc($pen, $x - 16, $topY + 20, 24, 16, 205, 150)
    $g.DrawLine($pen, $x - 18, $topY + 40, $x, $topY + 74)
    $g.DrawLine($pen, $x, $topY + 74, $x, $topY + 126)
    $pen.Dispose()
    return $topY + 126
}

function Draw-KMNC2($g, [float]$x, [float]$topY, [string]$label) {
    $pen = New-Pen 3
    Draw-RightText $g $label ($x - 18) ($topY + 18) 20 $true
    $g.DrawLine($pen, $x, $topY, $x, $topY + 26)
    $g.DrawLine($pen, $x, $topY + 26, $x, $topY + 48)
    $g.DrawLine($pen, $x, $topY + 48, $x + 18, $topY + 48)
    $g.DrawLine($pen, $x - 18, $topY + 58, $x, $topY + 86)
    $g.DrawLine($pen, $x, $topY + 86, $x, $topY + 126)
    $pen.Dispose()
    return $topY + 126
}

function Draw-FRNC($g, [float]$x, [float]$topY, [string]$label) {
    Draw-RightText $g $label ($x - 24) ($topY + 34) 20 $true
    Draw-AnchoredImage $g $script:FrNcVertical $x $topY 126 13 | Out-Null
    return $topY + 126
}

function Draw-KTNO($g, [float]$x, [float]$topY, [string]$label) {
    Draw-AnchoredImage $g $script:KtDelayNoGraphic $x $topY 126 30 | Out-Null
    Draw-Text $g $label ($x + 28) ($topY + 34) 18 $true
    return $topY + 126
}

function Draw-KTNOClean($g, [float]$x, [float]$topY, [string]$label) {
    Draw-AnchoredImage $g $script:KtDelayNoGraphic $x $topY 126 30 | Out-Null
    Draw-Text $g $label ($x + 18) ($topY + 28) 18 $true
    return $topY + 126
}

function Draw-KTNC($g, [float]$x, [float]$topY, [string]$label) {
    Draw-AnchoredImage $g $script:KtDelayNcGraphic $x $topY 126 9 | Out-Null
    Draw-Text $g $label ($x + 34) ($topY + 28) 18 $true
    return $topY + 126
}

function Draw-NoteBox($g, [float]$x, [float]$y, [float]$w, [float]$h, [string]$title, [string[]]$lines) {
    $pen = New-Pen 3
    $g.DrawRectangle($pen, $x, $y, $w, $h)
    $g.DrawLine($pen, $x, $y + 48, $x + $w, $y + 48)
    Draw-CenteredText $g $title ($x + ($w / 2)) ($y + 8) 24 $true
    $lineY = $y + 68
    foreach ($line in $lines) {
        Draw-Text $g $line ($x + 18) $lineY 20 $false
        $lineY += 42
    }
    $pen.Dispose()
}

function Draw-Project2() {
    $canvas = New-Canvas 2600 1500
    $g = $canvas.Graphics
    $pen = New-Pen 3

    Draw-Text $g '项目2第1题  两台电机顺序启动控制' 80 40 46 $true 'DarkGreen'
    Draw-Text $g '主电路' 170 110 30 $true
    Draw-Text $g '控制电路' 1120 110 30 $true

    $phaseXs = @(180, 260, 340)
    $bottomY = Draw-QSFUGroup $g $phaseXs 180
    foreach ($x in $phaseXs) {
        $g.DrawLine($pen, $x, $bottomY, $x, 470)
    }

    $phaseXs2 = @(520, 600, 680)
    for ($i = 0; $i -lt 3; $i++) {
        $g.DrawLine($pen, $phaseXs[$i], 380, $phaseXs2[$i], 380)
        $g.DrawLine($pen, $phaseXs2[$i], 380, $phaseXs2[$i], 470)
    }

    $km1Bottom = Draw-KMMain3 $g $phaseXs 470 'KM1'
    $km2Bottom = Draw-KMMain3 $g $phaseXs2 470 'KM2'
    $fr1Bottom = Draw-FRBlock3 $g $phaseXs $km1Bottom 'FR1'
    $fr2Bottom = Draw-FRBlock3 $g $phaseXs2 $km2Bottom 'FR2'
    Draw-Motor $g 260 $fr1Bottom 'M1'
    Draw-Motor $g 600 $fr2Bottom 'M2'

    foreach ($x in $phaseXs) {
        $g.DrawLine($pen, $x, $fr1Bottom, $x, $fr1Bottom + 20)
    }
    foreach ($x in $phaseXs2) {
        $g.DrawLine($pen, $x, $fr2Bottom, $x, $fr2Bottom + 20)
    }

    $busTopY = 190
    $busBottomY = 1290
    Draw-Terminal $g 930 $busTopY
    Draw-FuseH $g 960 $busTopY 74 'FU2'
    $g.DrawLine($pen, 1050, $busTopY, 2360, $busTopY)
    Draw-Text $g 'L' 900 152 28 $true
    Draw-Terminal $g 930 $busBottomY
    Draw-FuseH $g 960 $busBottomY 74 ''
    $g.DrawLine($pen, 1050, $busBottomY, 2360, $busBottomY)
    Draw-Text $g 'N' 898 1252 28 $true

    $c1 = 1340
    $c2 = 1700
    $c3 = 2060
    $sbTop = 250
    $frTop = 410
    $branchTop = 560
    $branchBottom = 720
    $branchSymbolTop = 578
    $coilTop = 930
    $ktTop = 700

    $g.DrawLine($pen, $c1, $busTopY, $c1, $sbTop)
    $y = Draw-SBNC $g $c1 $sbTop 'SB1'
    $g.DrawLine($pen, $c1, $y, $c1, $frTop)
    $y = Draw-FRNC $g $c1 $frTop 'FR1'
    $g.DrawLine($pen, $c1, $y, $c1, $branchTop)
    $g.DrawLine($pen, $c1, $branchTop, $c1 + 96, $branchTop)
    $g.DrawLine($pen, $c1, $branchBottom, $c1 + 96, $branchBottom)
    $g.DrawLine($pen, $c1, $branchTop, $c1, $branchSymbolTop)
    $y = Draw-SBNO $g $c1 $branchSymbolTop 'SB2'
    $g.DrawLine($pen, $c1, $y, $c1, $branchBottom)
    $g.DrawLine($pen, $c1 + 96, $branchTop, $c1 + 96, $branchSymbolTop)
    $y = Draw-KMNO $g ($c1 + 96) $branchSymbolTop 'KM1'
    $g.DrawLine($pen, $c1 + 96, $y, $c1 + 96, $branchBottom)
    $g.DrawLine($pen, $c1, $branchBottom, $c1, $coilTop)
    $coil1Bottom = Draw-Coil $g $c1 $coilTop 'KM1'
    $g.DrawLine($pen, $c1, $coil1Bottom, $c1, $busBottomY)

    $g.DrawLine($pen, $c2, $busTopY, $c2, $sbTop)
    $y = Draw-SBNC $g $c2 $sbTop 'SB1'
    $g.DrawLine($pen, $c2, $y, $c2, $frTop)
    $y = Draw-FRNC $g $c2 $frTop 'FR1'
    $g.DrawLine($pen, $c2, $y, $c2, $branchTop)
    $y = Draw-KMNO $g $c2 $branchTop 'KM1'
    $g.DrawLine($pen, $c2, $y, $c2, $coilTop)
    $coil2Bottom = Draw-TimerCoil $g $c2 $coilTop 'KT1 10s'
    $g.DrawLine($pen, $c2, $coil2Bottom, $c2, $busBottomY)

    $g.DrawLine($pen, $c3, $busTopY, $c3, $sbTop)
    $y = Draw-SBNC $g $c3 $sbTop 'SB1'
    $g.DrawLine($pen, $c3, $y, $c3, $frTop)
    $y = Draw-FRNC $g $c3 $frTop 'FR2'
    $g.DrawLine($pen, $c3, $y, $c3, $branchTop)
    $y = Draw-KMNO $g $c3 $branchTop 'KM1'
    $g.DrawLine($pen, $c3, $y, $c3, $ktTop)
    $y = Draw-KTNO $g $c3 $ktTop 'KT1'
    $g.DrawLine($pen, $c3, $y, $c3, $coilTop)
    $coil3Bottom = Draw-Coil $g $c3 $coilTop 'KM2'
    $g.DrawLine($pen, $c3, $coil3Bottom, $c3, $busBottomY)

    $pngPath = Join-Path $outDir '项目2-1_重制.png'
    $canvas.Bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose()
    $g.Dispose()
    $canvas.Bitmap.Dispose()
}

function Draw-Project3() {
    $canvas = New-Canvas 5000 2050
    $g = $canvas.Graphics
    $pen = New-Pen 3

    Draw-Text $g '项目3第6题  锅炉来煤系统三条皮带控制' 80 40 46 $true 'DarkGreen'
    Draw-Text $g '主电路' 170 110 30 $true
    Draw-Text $g '控制电路' 1220 110 30 $true

    $phaseXs = @(180, 260, 340)
    $bottomY = Draw-QSFUGroup $g $phaseXs 180
    foreach ($x in $phaseXs) {
        $g.DrawLine($pen, $x, $bottomY, $x, 430)
    }

    $branch1 = @(180, 260, 340)
    $branch2 = @(460, 540, 620)
    $branch3 = @(740, 820, 900)
    for ($i = 0; $i -lt 3; $i++) {
        $g.DrawLine($pen, $phaseXs[$i], 370, $branch2[$i], 370)
        $g.DrawLine($pen, $phaseXs[$i], 300, $branch3[$i], 300)
        $g.DrawLine($pen, $branch2[$i], 370, $branch2[$i], 430)
        $g.DrawLine($pen, $branch3[$i], 300, $branch3[$i], 430)
    }

    $km1Bottom = Draw-KMMain3 $g $branch1 430 'KM1'
    $km2Bottom = Draw-KMMain3 $g $branch2 430 'KM2'
    $km3Bottom = Draw-KMMain3 $g $branch3 430 'KM3'
    $fr1Bottom = Draw-FRBlock3 $g $branch1 $km1Bottom 'FR1'
    $fr2Bottom = Draw-FRBlock3 $g $branch2 $km2Bottom 'FR2'
    $fr3Bottom = Draw-FRBlock3 $g $branch3 $km3Bottom 'FR3'
    Draw-Motor $g 260 $fr1Bottom 'M1'
    Draw-Motor $g 540 $fr2Bottom 'M2'
    Draw-Motor $g 820 $fr3Bottom 'M3'
    foreach ($x in $branch1) { $g.DrawLine($pen, $x, $fr1Bottom, $x, $fr1Bottom + 18) }
    foreach ($x in $branch2) { $g.DrawLine($pen, $x, $fr2Bottom, $x, $fr2Bottom + 18) }
    foreach ($x in $branch3) { $g.DrawLine($pen, $x, $fr3Bottom, $x, $fr3Bottom + 18) }

    $busTopY = 190
    $busBottomY = 1760
    Draw-Terminal $g 1080 $busTopY
    Draw-FuseH $g 1110 $busTopY 78 'FU2'
    $g.DrawLine($pen, 1206, $busTopY, 4800, $busTopY)
    Draw-Text $g 'L' 1048 152 28 $true
    Draw-Terminal $g 1080 $busBottomY
    Draw-FuseH $g 1110 $busBottomY 78 ''
    $g.DrawLine($pen, 1206, $busBottomY, 4800, $busBottomY)
    Draw-Text $g 'N' 1048 1722 28 $true

    $cols = @{
        KM4 = 1260
        KM5 = 1610
        KT1 = 1960
        KT2 = 2310
        KT3 = 2660
        KT4 = 3010
        KT5 = 3360
        KM1 = 3740
        KM2 = 4130
        KM3 = 4520
    }

    $sbTop = 250
    $midTop = 410
    $thirdTop = 570
    $fourthTop = 740
    $nodeTop = 900
    $nodeBottom = 1060
    $coilTop = 1320

    $x = $cols.KM4
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-KMNC2 $g $x $midTop 'KM5'
    $g.DrawLine($pen, $x, $y, $x, $thirdTop)
    $g.DrawLine($pen, $x, $thirdTop, $x + 98, $thirdTop)
    $g.DrawLine($pen, $x, 730, $x + 98, 730)
    $g.DrawLine($pen, $x, $thirdTop, $x, 590)
    $y = Draw-SBNO $g $x 590 'SB1'
    $g.DrawLine($pen, $x, $y, $x, 730)
    $g.DrawLine($pen, $x + 98, $thirdTop, $x + 98, 590)
    $y = Draw-KMNO $g ($x + 98) 590 'KM4'
    $g.DrawLine($pen, $x + 98, $y, $x + 98, 730)
    $g.DrawLine($pen, $x, 730, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM4'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM5
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, 430)
    $g.DrawLine($pen, $x, 430, $x + 98, 430)
    $g.DrawLine($pen, $x, 600, $x + 98, 600)
    $g.DrawLine($pen, $x, 430, $x, 450)
    $y = Draw-SBNO $g $x 450 'SB2'
    $g.DrawLine($pen, $x, $y, $x, 600)
    $g.DrawLine($pen, $x + 98, 430, $x + 98, 450)
    $y = Draw-KMNO $g ($x + 98) 450 'KM5'
    $g.DrawLine($pen, $x + 98, $y, $x + 98, 600)
    $g.DrawLine($pen, $x, 600, $x, 760)
    $g.DrawLine($pen, $x, 760, $x - 98, 760)
    $g.DrawLine($pen, $x, 920, $x - 98, 920)
    $g.DrawLine($pen, $x, 760, $x, 780)
    $y = Draw-KMNO $g $x 780 'KM4'
    $g.DrawLine($pen, $x, $y, $x, 920)
    $g.DrawLine($pen, $x - 98, 760, $x - 98, 780)
    $y = Draw-KMNO $g ($x - 98) 780 'KM3'
    $g.DrawLine($pen, $x - 98, $y, $x - 98, 920)
    $g.DrawLine($pen, $x, 920, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM5'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT1
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-KMNO $g $x $midTop 'KM1'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT1 10s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT2
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-KMNO $g $x $midTop 'KM2'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT2 10s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT3
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-KMNO $g $x $midTop 'KM5'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT3 15s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT4
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-KMNO $g $x $midTop 'KM5'
    $g.DrawLine($pen, $x, $y, $x, $thirdTop)
    $g.DrawLine($pen, $x, $thirdTop, $x, ($thirdTop + 18))
    $y = Draw-KMNC2 $g $x ($thirdTop + 18) 'KM1'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT4 20s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT5
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-KMNO $g $x $midTop 'KM5'
    $g.DrawLine($pen, $x, $y, $x, $thirdTop)
    $g.DrawLine($pen, $x, $thirdTop, $x, ($thirdTop + 18))
    $y = Draw-KMNC2 $g $x ($thirdTop + 18) 'KM2'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT5 10s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM1
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-FRNC $g $x $midTop 'FR1'
    $g.DrawLine($pen, $x, $y, $x, $thirdTop)
    $y = Draw-KTNC $g $x $thirdTop 'KT3'
    $g.DrawLine($pen, $x, $y, $x, $fourthTop)
    $y = Draw-SBNC $g $x $fourthTop 'SB11'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 100, $nodeTop, $x + 100, $nodeTop)
    $g.DrawLine($pen, $x - 100, $nodeBottom, $x + 100, $nodeBottom)
    $g.DrawLine($pen, $x - 100, $nodeTop, $x - 100, 914)
    $y = Draw-KMNO $g ($x - 100) 914 'KM4'
    $g.DrawLine($pen, $x - 100, $y, $x - 100, $nodeBottom)
    $g.DrawLine($pen, $x, $nodeTop, $x, 914)
    $y = Draw-SBNO $g $x 914 'SB12'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottom)
    $g.DrawLine($pen, $x + 100, $nodeTop, $x + 100, 914)
    $y = Draw-KMNO $g ($x + 100) 914 'KM1'
    $g.DrawLine($pen, $x + 100, $y, $x + 100, $nodeBottom)
    $g.DrawLine($pen, $x, $nodeBottom, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM1'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM2
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-FRNC $g $x $midTop 'FR2'
    $g.DrawLine($pen, $x, $y, $x, $thirdTop)
    $y = Draw-KTNC $g $x $thirdTop 'KT4'
    $g.DrawLine($pen, $x, $y, $x, $fourthTop)
    $y = Draw-SBNC $g $x $fourthTop 'SB21'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x + 110, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeBottom, $x + 110, $nodeBottom)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x - 110, 914)
    $y = Draw-KMNO $g ($x - 110) 914 'KM4'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, 978)
    $y = Draw-KTNO $g ($x - 110) 978 'KT1'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, $nodeBottom)
    $g.DrawLine($pen, $x, $nodeTop, $x, 914)
    $y = Draw-SBNO $g $x 914 'SB22'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottom)
    $g.DrawLine($pen, $x + 110, $nodeTop, $x + 110, 914)
    $y = Draw-KMNO $g ($x + 110) 914 'KM2'
    $g.DrawLine($pen, $x + 110, $y, $x + 110, $nodeBottom)
    $g.DrawLine($pen, $x, $nodeBottom, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM2'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM3
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $midTop)
    $y = Draw-FRNC $g $x $midTop 'FR3'
    $g.DrawLine($pen, $x, $y, $x, $thirdTop)
    $y = Draw-KTNC $g $x $thirdTop 'KT5'
    $g.DrawLine($pen, $x, $y, $x, $fourthTop)
    $y = Draw-SBNC $g $x $fourthTop 'SB31'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x + 110, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeBottom, $x + 110, $nodeBottom)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x - 110, 914)
    $y = Draw-KMNO $g ($x - 110) 914 'KM4'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, 978)
    $y = Draw-KTNO $g ($x - 110) 978 'KT2'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, $nodeBottom)
    $g.DrawLine($pen, $x, $nodeTop, $x, 914)
    $y = Draw-SBNO $g $x 914 'SB32'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottom)
    $g.DrawLine($pen, $x + 110, $nodeTop, $x + 110, 914)
    $y = Draw-KMNO $g ($x + 110) 914 'KM3'
    $g.DrawLine($pen, $x + 110, $y, $x + 110, $nodeBottom)
    $g.DrawLine($pen, $x, $nodeBottom, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM3'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    Draw-Text $g 'SB1 集中启动   SB2 正常停车   SB0 急停' 1240 1820 26 $false
    Draw-Text $g '单台控制：SB11/SB12   SB21/SB22   SB31/SB32' 1240 1860 26 $false

    $pngPath = Join-Path $outDir '项目3-6_重制.png'
    $canvas.Bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose()
    $g.Dispose()
    $canvas.Bitmap.Dispose()
}

function Draw-Project3Compressed() {
    $canvas = New-Canvas 5000 2050
    $g = $canvas.Graphics
    $pen = New-Pen 3

    Draw-Text $g '项目3第6题  锅炉来煤系统三条皮带控制（压缩版）' 80 40 46 $true 'DarkGreen'
    Draw-Text $g '主电路' 170 110 30 $true
    Draw-Text $g '控制电路' 1220 110 30 $true

    $phaseXs = @(180, 260, 340)
    $bottomY = Draw-QSFUGroup $g $phaseXs 180
    foreach ($x in $phaseXs) {
        $g.DrawLine($pen, $x, $bottomY, $x, 430)
    }

    $branch1 = @(180, 260, 340)
    $branch2 = @(460, 540, 620)
    $branch3 = @(740, 820, 900)
    for ($i = 0; $i -lt 3; $i++) {
        $g.DrawLine($pen, $phaseXs[$i], 370, $branch2[$i], 370)
        $g.DrawLine($pen, $phaseXs[$i], 300, $branch3[$i], 300)
        $g.DrawLine($pen, $branch2[$i], 370, $branch2[$i], 430)
        $g.DrawLine($pen, $branch3[$i], 300, $branch3[$i], 430)
    }

    $km1Bottom = Draw-KMMain3 $g $branch1 430 'KM1'
    $km2Bottom = Draw-KMMain3 $g $branch2 430 'KM2'
    $km3Bottom = Draw-KMMain3 $g $branch3 430 'KM3'
    $fr1Bottom = Draw-FRBlock3 $g $branch1 $km1Bottom 'FR1'
    $fr2Bottom = Draw-FRBlock3 $g $branch2 $km2Bottom 'FR2'
    $fr3Bottom = Draw-FRBlock3 $g $branch3 $km3Bottom 'FR3'
    Draw-Motor $g 260 $fr1Bottom 'M1'
    Draw-Motor $g 540 $fr2Bottom 'M2'
    Draw-Motor $g 820 $fr3Bottom 'M3'
    foreach ($x in $branch1) { $g.DrawLine($pen, $x, $fr1Bottom, $x, $fr1Bottom + 18) }
    foreach ($x in $branch2) { $g.DrawLine($pen, $x, $fr2Bottom, $x, $fr2Bottom + 18) }
    foreach ($x in $branch3) { $g.DrawLine($pen, $x, $fr3Bottom, $x, $fr3Bottom + 18) }

    $busTopY = 190
    $busBottomY = 1760
    Draw-Terminal $g 1080 $busTopY
    Draw-FuseH $g 1110 $busTopY 78 'FU2'
    $g.DrawLine($pen, 1206, $busTopY, 4800, $busTopY)
    Draw-Text $g 'L' 1048 152 28 $true
    Draw-Terminal $g 1080 $busBottomY
    Draw-FuseH $g 1110 $busBottomY 78 ''
    $g.DrawLine($pen, 1206, $busBottomY, 4800, $busBottomY)
    Draw-Text $g 'N' 1048 1722 28 $true

    $cols = @{
        KM4 = 1280
        KM5 = 1680
        KM1 = 2420
        KM2 = 3270
        KM3 = 4120
    }

    $sbTop = 250
    $frTop = 410
    $ktTop = 570
    $singleStopTop = 730
    $nodeTop = 900
    $nodeBottomShort = 1060
    $nodeBottomLong = 1220
    $coilTop = 1430

    $x = $cols.KM4
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-KMNC2 $g $x $frTop 'KM5'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $g.DrawLine($pen, $x, $ktTop, $x + 100, $ktTop)
    $g.DrawLine($pen, $x, $singleStopTop, $x + 100, $singleStopTop)
    $g.DrawLine($pen, $x, $ktTop, $x, 590)
    $y = Draw-SBNO $g $x 590 'SB1'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $g.DrawLine($pen, $x + 100, $ktTop, $x + 100, 590)
    $y = Draw-KMNO $g ($x + 100) 590 'KM4'
    $g.DrawLine($pen, $x + 100, $y, $x + 100, $singleStopTop)
    $g.DrawLine($pen, $x, $singleStopTop, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM4'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM5
    $km5RightX1 = $x + 140
    $km5RightX2 = $x + 160
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, 430)
    $g.DrawLine($pen, $x, 430, $km5RightX1, 430)
    $g.DrawLine($pen, $x, 600, $km5RightX1, 600)
    $g.DrawLine($pen, $x, 430, $x, 450)
    $y = Draw-SBNO $g $x 450 'SB2'
    $g.DrawLine($pen, $x, $y, $x, 600)
    $g.DrawLine($pen, $km5RightX1, 430, $km5RightX1, 450)
    $y = Draw-KMNO $g $km5RightX1 450 'KM5'
    $g.DrawLine($pen, $km5RightX1, $y, $km5RightX1, 600)
    $g.DrawLine($pen, $x, 600, $x, 760)
    $g.DrawLine($pen, $x, 760, $km5RightX2, 760)
    $g.DrawLine($pen, $x, 920, $km5RightX2, 920)
    $g.DrawLine($pen, $x, 760, $x, 780)
    $y = Draw-KMNO $g $x 780 'KM4'
    $g.DrawLine($pen, $x, $y, $x, 920)
    $g.DrawLine($pen, $km5RightX2, 760, $km5RightX2, 780)
    $y = Draw-KMNO $g $km5RightX2 780 'KM3'
    $g.DrawLine($pen, $km5RightX2, $y, $km5RightX2, 920)
    $g.DrawLine($pen, $x, 920, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM5'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM1
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR1'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT3'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB11'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 100, $nodeTop, $x + 100, $nodeTop)
    $g.DrawLine($pen, $x - 100, $nodeBottomShort, $x + 100, $nodeBottomShort)
    $g.DrawLine($pen, $x - 100, $nodeTop, $x - 100, 914)
    $y = Draw-KMNO $g ($x - 100) 914 'KM4'
    $g.DrawLine($pen, $x - 100, $y, $x - 100, $nodeBottomShort)
    $g.DrawLine($pen, $x, $nodeTop, $x, 914)
    $y = Draw-SBNO $g $x 914 'SB12'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomShort)
    $g.DrawLine($pen, $x + 100, $nodeTop, $x + 100, 914)
    $y = Draw-KMNO $g ($x + 100) 914 'KM1'
    $g.DrawLine($pen, $x + 100, $y, $x + 100, $nodeBottomShort)
    $g.DrawLine($pen, $x, $nodeBottomShort, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM1'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM2
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR2'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT4'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB21'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x + 110, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeBottomLong, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x - 120, 914)
    $y = Draw-KMNO $g ($x - 120) 914 'KM4'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, 1050)
    $y = Draw-KTNO $g ($x - 120) 1050 'KT1'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeTop, $x, 970)
    $y = Draw-SBNO $g $x 970 'SB22'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomLong)
    $g.DrawLine($pen, $x + 110, $nodeTop, $x + 110, 970)
    $y = Draw-KMNO $g ($x + 110) 970 'KM2'
    $g.DrawLine($pen, $x + 110, $y, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeBottomLong, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM2'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM3
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR3'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT5'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB31'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x + 110, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeBottomLong, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x - 120, 914)
    $y = Draw-KMNO $g ($x - 120) 914 'KM4'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, 1050)
    $y = Draw-KTNO $g ($x - 120) 1050 'KT2'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeTop, $x, 970)
    $y = Draw-SBNO $g $x 970 'SB32'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomLong)
    $g.DrawLine($pen, $x + 110, $nodeTop, $x + 110, 970)
    $y = Draw-KMNO $g ($x + 110) 970 'KM3'
    $g.DrawLine($pen, $x + 110, $y, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeBottomLong, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM3'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    Draw-NoteBox $g 4350 360 390 360 '顺序关系' @(
        'KM4：集中启动保持'
        'KM5：正常停车保持'
        'KT1：KM1 吸合 10s 后闭合'
        'KT2：KM2 吸合 10s 后闭合'
        'KT3：顺停 15s 后断开 M1'
        'KT4：顺停 20s 后断开 M2'
        'KT5：顺停 10s 后断开 M3'
    )

    Draw-Text $g 'SB1 集中启动   SB2 正常停车   SB0 急停' 1240 1820 26 $false
    Draw-Text $g '单台控制：SB11/SB12   SB21/SB22   SB31/SB32' 1240 1860 26 $false
    Draw-Text $g '压缩版将 KT1-KT5 的线圈并入说明区，只保留主控制支路。' 1240 1900 26 $false

    $pngPath = Join-Path $compressedDir '项目3-6_压缩版.png'
    $canvas.Bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose()
    $g.Dispose()
    $canvas.Bitmap.Dispose()
}

function Draw-Project3Clean() {
    $canvas = New-Canvas 5000 2050
    $g = $canvas.Graphics
    $pen = New-Pen 3

    Draw-Text $g '项目3第6题  锅炉来煤系统三条皮带控制（整理版）' 80 40 46 $true 'DarkGreen'
    Draw-Text $g '主电路' 170 110 30 $true
    Draw-Text $g '控制电路' 1220 110 30 $true

    $phaseXs = @(180, 260, 340)
    $bottomY = Draw-QSFUGroup $g $phaseXs 180
    foreach ($x in $phaseXs) {
        $g.DrawLine($pen, $x, $bottomY, $x, 430)
    }

    $branch1 = @(180, 260, 340)
    $branch2 = @(460, 540, 620)
    $branch3 = @(740, 820, 900)
    for ($i = 0; $i -lt 3; $i++) {
        $g.DrawLine($pen, $phaseXs[$i], 370, $branch2[$i], 370)
        $g.DrawLine($pen, $phaseXs[$i], 300, $branch3[$i], 300)
        $g.DrawLine($pen, $branch2[$i], 370, $branch2[$i], 430)
        $g.DrawLine($pen, $branch3[$i], 300, $branch3[$i], 430)
    }

    $km1Bottom = Draw-KMMain3 $g $branch1 430 'KM1'
    $km2Bottom = Draw-KMMain3 $g $branch2 430 'KM2'
    $km3Bottom = Draw-KMMain3 $g $branch3 430 'KM3'
    $fr1Bottom = Draw-FRBlock3 $g $branch1 $km1Bottom 'FR1'
    $fr2Bottom = Draw-FRBlock3 $g $branch2 $km2Bottom 'FR2'
    $fr3Bottom = Draw-FRBlock3 $g $branch3 $km3Bottom 'FR3'
    Draw-Motor $g 260 $fr1Bottom 'M1'
    Draw-Motor $g 540 $fr2Bottom 'M2'
    Draw-Motor $g 820 $fr3Bottom 'M3'
    foreach ($x in $branch1) { $g.DrawLine($pen, $x, $fr1Bottom, $x, $fr1Bottom + 18) }
    foreach ($x in $branch2) { $g.DrawLine($pen, $x, $fr2Bottom, $x, $fr2Bottom + 18) }
    foreach ($x in $branch3) { $g.DrawLine($pen, $x, $fr3Bottom, $x, $fr3Bottom + 18) }

    $busTopY = 190
    $busBottomY = 1760
    Draw-Terminal $g 1080 $busTopY
    Draw-FuseH $g 1110 $busTopY 78 'FU2'
    $g.DrawLine($pen, 1206, $busTopY, 4800, $busTopY)
    Draw-Text $g 'L' 1048 152 28 $true
    Draw-Terminal $g 1080 $busBottomY
    Draw-FuseH $g 1110 $busBottomY 78 ''
    $g.DrawLine($pen, 1206, $busBottomY, 4800, $busBottomY)
    Draw-Text $g 'N' 1048 1722 28 $true

    $cols = @{
        KM4 = 1280
        KM5 = 1650
        KT1 = 2070
        KT2 = 2440
        KM1 = 3160
        KM2 = 3930
        KM3 = 4680
    }

    $sbTop = 250
    $frTop = 410
    $ktTop = 570
    $singleStopTop = 730
    $nodeTop = 900
    $nodeBottomShort = 1060
    $nodeBottomLong = 1220
    $coilTop = 1430

    $x = $cols.KM4
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-KMNC2 $g $x $frTop 'KM5'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $g.DrawLine($pen, $x, $ktTop, $x + 100, $ktTop)
    $g.DrawLine($pen, $x, $singleStopTop, $x + 100, $singleStopTop)
    $g.DrawLine($pen, $x, $ktTop, $x, 590)
    $y = Draw-SBNO $g $x 590 'SB1'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $g.DrawLine($pen, $x + 100, $ktTop, $x + 100, 590)
    $y = Draw-KMNO $g ($x + 100) 590 'KM4'
    $g.DrawLine($pen, $x + 100, $y, $x + 100, $singleStopTop)
    $g.DrawLine($pen, $x, $singleStopTop, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM4'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM5
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, 430)
    $g.DrawLine($pen, $x, 430, $x + 120, 430)
    $g.DrawLine($pen, $x, 600, $x + 120, 600)
    $g.DrawLine($pen, $x, 430, $x, 450)
    $y = Draw-SBNO $g $x 450 'SB2'
    $g.DrawLine($pen, $x, $y, $x, 600)
    $g.DrawLine($pen, $x + 120, 430, $x + 120, 450)
    $y = Draw-KMNO $g ($x + 120) 450 'KM5'
    $g.DrawLine($pen, $x + 120, $y, $x + 120, 600)
    $g.DrawLine($pen, $x, 600, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM5'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT1
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-KMNO $g $x $frTop 'KM1'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT1 10s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT2
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-KMNO $g $x $frTop 'KM2'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT2 10s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM1
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR1'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT3'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB11'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 100, $nodeTop, $x + 100, $nodeTop)
    $g.DrawLine($pen, $x - 100, $nodeBottomShort, $x + 100, $nodeBottomShort)
    $g.DrawLine($pen, $x - 100, $nodeTop, $x - 100, 914)
    $y = Draw-KMNO $g ($x - 100) 914 'KM4'
    $g.DrawLine($pen, $x - 100, $y, $x - 100, $nodeBottomShort)
    $g.DrawLine($pen, $x, $nodeTop, $x, 914)
    $y = Draw-SBNO $g $x 914 'SB12'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomShort)
    $g.DrawLine($pen, $x + 100, $nodeTop, $x + 100, 914)
    $y = Draw-KMNO $g ($x + 100) 914 'KM1'
    $g.DrawLine($pen, $x + 100, $y, $x + 100, $nodeBottomShort)
    $g.DrawLine($pen, $x, $nodeBottomShort, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM1'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM2
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR2'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT4'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB21'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x + 110, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeBottomLong, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x - 120, 914)
    $y = Draw-KMNO $g ($x - 120) 914 'KM4'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, 978)
    $y = Draw-KTNO $g ($x - 120) 978 'KT1'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeTop, $x, 914)
    $y = Draw-SBNO $g $x 914 'SB22'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomLong)
    $g.DrawLine($pen, $x + 110, $nodeTop, $x + 110, 914)
    $y = Draw-KMNO $g ($x + 110) 914 'KM2'
    $g.DrawLine($pen, $x + 110, $y, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeBottomLong, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM2'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM3
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR3'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT5'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB31'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x + 110, $nodeTop)
    $g.DrawLine($pen, $x - 120, $nodeBottomLong, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x - 120, $nodeTop, $x - 120, 914)
    $y = Draw-KMNO $g ($x - 120) 914 'KM4'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, 978)
    $y = Draw-KTNO $g ($x - 120) 978 'KT2'
    $g.DrawLine($pen, $x - 120, $y, $x - 120, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeTop, $x, 914)
    $y = Draw-SBNO $g $x 914 'SB32'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomLong)
    $g.DrawLine($pen, $x + 110, $nodeTop, $x + 110, 914)
    $y = Draw-KMNO $g ($x + 110) 914 'KM3'
    $g.DrawLine($pen, $x + 110, $y, $x + 110, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeBottomLong, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM3'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    Draw-NoteBox $g 4320 360 420 280 '顺停说明' @(
        'KT3：KM5 吸合后延时 15s 断开 KM1'
        'KT4：KM5 吸合后延时 20s 断开 KM2'
        'KT5：KM5 吸合后延时 10s 断开 KM3'
        'KT1、KT2 线圈单独列出，便于看顺启'
    )

    Draw-Text $g 'SB1 集中启动   SB2 正常停车   SB0 急停' 1240 1820 26 $false
    Draw-Text $g '单台控制：SB11/SB12   SB21/SB22   SB31/SB32' 1240 1860 26 $false

    $pngPath = Join-Path $root '成图输出\项目3-6_整理版.png'
    $canvas.Bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose()
    $g.Dispose()
    $canvas.Bitmap.Dispose()
}

function Draw-Project2Final() {
    $canvas = New-Canvas 2120 1180
    $g = $canvas.Graphics
    $pen = New-Pen 3

    Draw-Text $g '项目2第1题  两台电机顺序启动控制' 40 26 42 $true 'DarkGreen'
    Draw-Text $g '主电路' 120 92 28 $true
    Draw-Text $g '控制电路' 900 92 28 $true

    $phaseXs = @(140, 220, 300)
    $bottomY = Draw-QSFUGroup $g $phaseXs 160
    foreach ($x in $phaseXs) {
        $g.DrawLine($pen, $x, $bottomY, $x, 430)
    }

    $phaseXs2 = @(420, 500, 580)
    for ($i = 0; $i -lt 3; $i++) {
        $g.DrawLine($pen, $phaseXs[$i], 350, $phaseXs2[$i], 350)
        $g.DrawLine($pen, $phaseXs2[$i], 350, $phaseXs2[$i], 430)
    }

    $km1Bottom = Draw-KMMain3 $g $phaseXs 430 'KM1'
    $km2Bottom = Draw-KMMain3 $g $phaseXs2 430 'KM2'
    $fr1Bottom = Draw-FRBlock3 $g $phaseXs $km1Bottom 'FR1'
    $fr2Bottom = Draw-FRBlock3 $g $phaseXs2 $km2Bottom 'FR2'
    Draw-MotorWithTerminals $g $phaseXs $fr1Bottom 'M1' | Out-Null
    Draw-MotorWithTerminals $g $phaseXs2 $fr2Bottom 'M2' | Out-Null

    $busTopY = 160
    $busBottomY = 1040
    Draw-Terminal $g 820 $busTopY
    Draw-FuseH $g 850 $busTopY 70 'FU2'
    $g.DrawLine($pen, 936, $busTopY, 1838, $busTopY)
    Draw-Text $g 'L' 820 124 26 $true
    Draw-Terminal $g 820 $busBottomY
    Draw-FuseH $g 850 $busBottomY 70 ''
    $g.DrawLine($pen, 936, $busBottomY, 1838, $busBottomY)
    Draw-Text $g 'N' 818 1044 26 $true

    $c1 = 1150
    $c2 = 1430
    $c3 = 1710
    $sbTop = 210
    $frTop = 350
    $branchTop = 490
    $branchBottom = 640
    $branchSymbolTop = 510
    $coilTop = 780
    $ktTop = 620

    $g.DrawLine($pen, $c1, $busTopY, $c1, $sbTop)
    $y = Draw-SBNC $g $c1 $sbTop 'SB1'
    $g.DrawLine($pen, $c1, $y, $c1, $frTop)
    $y = Draw-FRNC $g $c1 $frTop 'FR1'
    $g.DrawLine($pen, $c1, $y, $c1, $branchTop)
    $g.DrawLine($pen, $c1, $branchTop, $c1 + 96, $branchTop)
    $g.DrawLine($pen, $c1, $branchBottom, $c1 + 96, $branchBottom)
    $g.DrawLine($pen, $c1, $branchTop, $c1, $branchSymbolTop)
    $y = Draw-SBNO $g $c1 $branchSymbolTop 'SB2'
    $g.DrawLine($pen, $c1, $y, $c1, $branchBottom)
    $g.DrawLine($pen, $c1 + 96, $branchTop, $c1 + 96, $branchSymbolTop)
    $y = Draw-KMNO $g ($c1 + 96) $branchSymbolTop 'KM1'
    $g.DrawLine($pen, $c1 + 96, $y, $c1 + 96, $branchBottom)
    $g.DrawLine($pen, $c1, $branchBottom, $c1, $coilTop)
    $coil1Bottom = Draw-Coil $g $c1 $coilTop 'KM1'
    $g.DrawLine($pen, $c1, $coil1Bottom, $c1, $busBottomY)

    $g.DrawLine($pen, $c2, $busTopY, $c2, $sbTop)
    $y = Draw-SBNC $g $c2 $sbTop 'SB1'
    $g.DrawLine($pen, $c2, $y, $c2, $frTop)
    $y = Draw-FRNC $g $c2 $frTop 'FR1'
    $g.DrawLine($pen, $c2, $y, $c2, $branchTop)
    $y = Draw-KMNO $g $c2 $branchTop 'KM1'
    $g.DrawLine($pen, $c2, $y, $c2, $coilTop)
    $coil2Bottom = Draw-TimerCoil $g $c2 $coilTop 'KT1 10s'
    $g.DrawLine($pen, $c2, $coil2Bottom, $c2, $busBottomY)

    $g.DrawLine($pen, $c3, $busTopY, $c3, $sbTop)
    $y = Draw-SBNC $g $c3 $sbTop 'SB1'
    $g.DrawLine($pen, $c3, $y, $c3, $frTop)
    $y = Draw-FRNC $g $c3 $frTop 'FR2'
    $g.DrawLine($pen, $c3, $y, $c3, $branchTop)
    $y = Draw-KMNO $g $c3 $branchTop 'KM1'
    $g.DrawLine($pen, $c3, $y, $c3, $ktTop)
    $y = Draw-KTNOClean $g $c3 $ktTop 'KT1'
    $g.DrawLine($pen, $c3, $y, $c3, $coilTop)
    $coil3Bottom = Draw-Coil $g $c3 $coilTop 'KM2'
    $g.DrawLine($pen, $c3, $coil3Bottom, $c3, $busBottomY)

    $pngPath = Join-Path $finalDir '项目2-1_成品.png'
    Save-TrimmedPng $canvas.Bitmap $pngPath
    $pen.Dispose()
    $g.Dispose()
    $canvas.Bitmap.Dispose()
}

function Draw-Project3Final() {
    $canvas = New-Canvas 3620 1600
    $g = $canvas.Graphics
    $pen = New-Pen 3

    Draw-Text $g '项目3第6题  锅炉来煤系统三条皮带控制' 40 26 42 $true 'DarkGreen'
    Draw-Text $g '主电路' 120 92 28 $true
    Draw-Text $g '控制电路' 930 92 28 $true

    $phaseXs = @(140, 220, 300)
    $bottomY = Draw-QSFUGroup $g $phaseXs 160
    foreach ($x in $phaseXs) { $g.DrawLine($pen, $x, $bottomY, $x, 420) }

    $branch1 = @(140, 220, 300)
    $branch2 = @(420, 500, 580)
    $branch3 = @(700, 780, 860)
    for ($i = 0; $i -lt 3; $i++) {
        $g.DrawLine($pen, $phaseXs[$i], 350, $branch2[$i], 350)
        $g.DrawLine($pen, $phaseXs[$i], 285, $branch3[$i], 285)
        $g.DrawLine($pen, $branch2[$i], 350, $branch2[$i], 420)
        $g.DrawLine($pen, $branch3[$i], 285, $branch3[$i], 420)
    }

    $km1Bottom = Draw-KMMain3 $g $branch1 420 'KM1'
    $km2Bottom = Draw-KMMain3 $g $branch2 420 'KM2'
    $km3Bottom = Draw-KMMain3 $g $branch3 420 'KM3'
    $fr1Bottom = Draw-FRBlock3 $g $branch1 $km1Bottom 'FR1'
    $fr2Bottom = Draw-FRBlock3 $g $branch2 $km2Bottom 'FR2'
    $fr3Bottom = Draw-FRBlock3 $g $branch3 $km3Bottom 'FR3'
    Draw-MotorWithTerminals $g $branch1 $fr1Bottom 'M1' | Out-Null
    Draw-MotorWithTerminals $g $branch2 $fr2Bottom 'M2' | Out-Null
    Draw-MotorWithTerminals $g $branch3 $fr3Bottom 'M3' | Out-Null

    $busTopY = 160
    $busBottomY = 1450
    Draw-Terminal $g 900 $busTopY
    Draw-FuseH $g 930 $busTopY 72 'FU2'
    $g.DrawLine($pen, 1020, $busTopY, 3256, $busTopY)
    Draw-Text $g 'L' 890 124 26 $true
    Draw-Terminal $g 900 $busBottomY
    Draw-FuseH $g 930 $busBottomY 72 ''
    $g.DrawLine($pen, 1020, $busBottomY, 3256, $busBottomY)
    Draw-Text $g 'N' 888 1434 26 $true

    $cols = @{
        KM4 = 1080
        KM5 = 1310
        KT1 = 1540
        KT2 = 1770
        KM1 = 2220
        KM2 = 2720
        KM3 = 3220
    }

    $sbTop = 210
    $frTop = 350
    $ktTop = 500
    $singleStopTop = 650
    $nodeTop = 800
    $nodeBottomShort = 940
    $nodeBottomLong = 1080
    $coilTop = 1210

    $x = $cols.KM4
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-KMNC2 $g $x $frTop 'KM5'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $g.DrawLine($pen, $x, $ktTop, $x + 92, $ktTop)
    $g.DrawLine($pen, $x, $singleStopTop, $x + 92, $singleStopTop)
    $g.DrawLine($pen, $x, $ktTop, $x, 520)
    $y = Draw-SBNO $g $x 520 'SB1'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $g.DrawLine($pen, $x + 92, $ktTop, $x + 92, 520)
    $y = Draw-KMNO $g ($x + 92) 520 'KM4'
    $g.DrawLine($pen, $x + 92, $y, $x + 92, $singleStopTop)
    $g.DrawLine($pen, $x, $singleStopTop, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM4'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM5
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, 410)
    $g.DrawLine($pen, $x, 410, $x + 108, 410)
    $g.DrawLine($pen, $x, 580, $x + 108, 580)
    $g.DrawLine($pen, $x, 410, $x, 430)
    $y = Draw-SBNO $g $x 430 'SB2'
    $g.DrawLine($pen, $x, $y, $x, 580)
    $g.DrawLine($pen, $x + 108, 410, $x + 108, 430)
    $y = Draw-KMNO $g ($x + 108) 430 'KM5'
    $g.DrawLine($pen, $x + 108, $y, $x + 108, 580)
    $g.DrawLine($pen, $x, 580, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM5'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT1
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-KMNO $g $x $frTop 'KM1'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT1 10s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KT2
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-KMNO $g $x $frTop 'KM2'
    $g.DrawLine($pen, $x, $y, $x, $coilTop)
    $coilBottom = Draw-TimerCoil $g $x $coilTop 'KT2 10s'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM1
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR1'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT3'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB11'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 92, $nodeTop, $x + 92, $nodeTop)
    $g.DrawLine($pen, $x - 92, $nodeBottomShort, $x + 92, $nodeBottomShort)
    $g.DrawLine($pen, $x - 92, $nodeTop, $x - 92, 814)
    $y = Draw-KMNO $g ($x - 92) 814 'KM4'
    $g.DrawLine($pen, $x - 92, $y, $x - 92, $nodeBottomShort)
    $g.DrawLine($pen, $x, $nodeTop, $x, 814)
    $y = Draw-SBNO $g $x 814 'SB12'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomShort)
    $g.DrawLine($pen, $x + 92, $nodeTop, $x + 92, 814)
    $y = Draw-KMNO $g ($x + 92) 814 'KM1'
    $g.DrawLine($pen, $x + 92, $y, $x + 92, $nodeBottomShort)
    $g.DrawLine($pen, $x, $nodeBottomShort, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM1'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM2
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR2'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT4'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB21'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x + 98, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeBottomLong, $x + 98, $nodeBottomLong)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x - 110, 814)
    $y = Draw-KMNO $g ($x - 110) 814 'KM4'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, 888)
    $y = Draw-KTNOClean $g ($x - 110) 888 'KT1'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeTop, $x, 814)
    $y = Draw-SBNO $g $x 814 'SB22'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomLong)
    $g.DrawLine($pen, $x + 98, $nodeTop, $x + 98, 814)
    $y = Draw-KMNO $g ($x + 98) 814 'KM2'
    $g.DrawLine($pen, $x + 98, $y, $x + 98, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeBottomLong, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM2'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    $x = $cols.KM3
    $g.DrawLine($pen, $x, $busTopY, $x, $sbTop)
    $y = Draw-SBNC $g $x $sbTop 'SB0'
    $g.DrawLine($pen, $x, $y, $x, $frTop)
    $y = Draw-FRNC $g $x $frTop 'FR3'
    $g.DrawLine($pen, $x, $y, $x, $ktTop)
    $y = Draw-KTNC $g $x $ktTop 'KT5'
    $g.DrawLine($pen, $x, $y, $x, $singleStopTop)
    $y = Draw-SBNC $g $x $singleStopTop 'SB31'
    $g.DrawLine($pen, $x, $y, $x, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x + 98, $nodeTop)
    $g.DrawLine($pen, $x - 110, $nodeBottomLong, $x + 98, $nodeBottomLong)
    $g.DrawLine($pen, $x - 110, $nodeTop, $x - 110, 814)
    $y = Draw-KMNO $g ($x - 110) 814 'KM4'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, 888)
    $y = Draw-KTNOClean $g ($x - 110) 888 'KT2'
    $g.DrawLine($pen, $x - 110, $y, $x - 110, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeTop, $x, 814)
    $y = Draw-SBNO $g $x 814 'SB32'
    $g.DrawLine($pen, $x, $y, $x, $nodeBottomLong)
    $g.DrawLine($pen, $x + 98, $nodeTop, $x + 98, 814)
    $y = Draw-KMNO $g ($x + 98) 814 'KM3'
    $g.DrawLine($pen, $x + 98, $y, $x + 98, $nodeBottomLong)
    $g.DrawLine($pen, $x, $nodeBottomLong, $x, $coilTop)
    $coilBottom = Draw-Coil $g $x $coilTop 'KM3'
    $g.DrawLine($pen, $x, $coilBottom, $x, $busBottomY)

    Draw-Text $g 'SB1 集中启动   SB2 正常停车   SB0 急停   单台：SB11/SB12  SB21/SB22  SB31/SB32' 1000 1480 20 $false
    Draw-Text $g '顺启：KT1 由 KM1 吸合触发，KT2 由 KM2 吸合触发。' 1000 1510 20 $false
    Draw-Text $g '顺停：KT3 15s 断 KM1，KT4 20s 断 KM2，KT5 10s 断 KM3。' 1000 1540 20 $false

    $pngPath = Join-Path $finalDir '项目3-6_成品.png'
    Save-TrimmedPng $canvas.Bitmap $pngPath
    $pen.Dispose()
    $g.Dispose()
    $canvas.Bitmap.Dispose()
}

Draw-Project2Final
Draw-Project3Final

$script:KtDelayNoGraphic.Dispose()
$script:KtDelayNcGraphic.Dispose()
$script:FrNcVertical.Dispose()

