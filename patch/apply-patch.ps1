# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    把 AnLink 3.10 的 ScreenEncoder.smali 改造成 Android 14+ 兼容版本。

.DESCRIPTION
    就地修改 baksmali 出来的源码树，涉及方法：
        createDisplay        -> 按 SDK_INT 分流，34+ 返回 null
        createDisplayLegacy  -> 新增，保存原始实现
        createVirtualDisplay -> 新增，反射调用 DisplayManager.createVirtualDisplay
        setDisplaySurface    -> 前缀分流 + catchall 回退
        destroyDisplay       -> null 时释放 VirtualDisplay
        setScreenPowerMode   -> Android 14+ 通过 DisplayControl 操作所有物理显示
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SmaliDir,
    [Parameter(Mandatory = $true)][string]$PatchDir
)

$ErrorActionPreference = "Stop"
$target = Join-Path $SmaliDir "ink\anl\ScreenEncoder.smali"
if (-not (Test-Path $target)) { throw ("找不到 " + $target) }
$deviceTarget = Join-Path $SmaliDir "ink\anl\Device.smali"
if (-not (Test-Path $deviceTarget)) { throw ("找不到 " + $deviceTarget) }
$surfaceControlTarget = Join-Path $SmaliDir "ink\anl\wrappers\SurfaceControl.smali"
if (-not (Test-Path $surfaceControlTarget)) { throw ("找不到 " + $surfaceControlTarget) }

function Get-MethodRange {
    param([string]$Text, [string]$Signature)
    $i = $Text.IndexOf($Signature)
    if ($i -lt 0) { throw ("找不到方法: " + $Signature) }
    $j = $Text.IndexOf(".end method", $i)
    if ($j -lt 0) { throw ("方法未闭合: " + $Signature) }
    return @{ Start = $i; End = ($j + ".end method".Length) }
}

function Read-Fragment {
    param([string]$Name)
    $text = [IO.File]::ReadAllText((Join-Path $PatchDir $Name), [Text.Encoding]::UTF8)
    return $text.TrimEnd() + [Environment]::NewLine
}

$nl = [Environment]::NewLine
$text = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)

# 1) 新增静态字段
if ($text -notmatch "virtualDisplay:Landroid/hardware/display/VirtualDisplay;") {
    $anchor = ".field private static final REPEAT_FRAME_DELAY_US:I = 0x186a0"
    if ($text.IndexOf($anchor) -lt 0) { throw "找不到字段锚点 REPEAT_FRAME_DELAY_US" }
    $ins = ".field private static virtualDisplay:Landroid/hardware/display/VirtualDisplay;"
    $text = $text.Replace($anchor, $anchor + $nl + $nl + $ins)
}

# 2-5) 显示创建补丁。
# 已打过 v1 补丁时跳过这一段，便于从现有已修补的 an-link 重建新版本。
$displayPatchApplied = $text.Contains("virtualDisplay:Landroid/hardware/display/VirtualDisplay;") -and
    $text.Contains(".method private static createDisplayLegacy()Landroid/os/IBinder;")
if ($displayPatchApplied) {
    Write-Host "ScreenEncoder 显示补丁已存在，跳过。"
} else {
    # createDisplay -> 分流版本 + createDisplayLegacy
    $r = Get-MethodRange $text ".method private static createDisplay()Landroid/os/IBinder;"
    $repl = (Read-Fragment "01-createDisplay.smali") + (Read-Fragment "02-createDisplayLegacy.smali")
    $text = $text.Substring(0, $r.Start) + $repl + $text.Substring($r.End)

    # destroyDisplay
    $r = Get-MethodRange $text ".method private static destroyDisplay(Landroid/os/IBinder;)V"
    $text = $text.Substring(0, $r.Start) + (Read-Fragment "05-destroyDisplay.smali") + $text.Substring($r.End)

    # setDisplaySurface：保留原方法体（从 openTransaction 起），前面插入分流逻辑
    $r = Get-MethodRange $text ".method private static setDisplaySurface("
    $block = $text.Substring($r.Start, $r.End - $r.Start)
    $bodyStart = $block.IndexOf("invoke-static {}, Link/anl/wrappers/SurfaceControl;->openTransaction()V")
    if ($bodyStart -lt 0) { throw "setDisplaySurface 结构不符合预期（找不到 openTransaction）" }
    $originalBody = $block.Substring($bodyStart)
    $frag = [IO.File]::ReadAllText((Join-Path $PatchDir "04-setDisplaySurface.smali"), [Text.Encoding]::UTF8)
    $marker = ":legacy"
    $idx = $frag.LastIndexOf($marker)
    if ($idx -lt 0) { throw "04-setDisplaySurface.smali 缺少 :legacy 标记" }
    $head = $frag.Substring(0, $idx + $marker.Length)
    $newBlock = $head + $nl + $originalBody
    $text = $text.Substring(0, $r.Start) + $newBlock + $text.Substring($r.End)

    # createVirtualDisplay 追加到文件末尾
    if ($text.IndexOf(".method private static createVirtualDisplay(") -lt 0) {
        $text = $text.TrimEnd() + $nl + $nl + (Read-Fragment "03-createVirtualDisplay.smali")
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($target, $text, $utf8NoBom)

# 6) 息屏控制：Android 14 把物理显示 API 移到了 services.jar 的 DisplayControl。
$deviceText = [IO.File]::ReadAllText($deviceTarget, [Text.Encoding]::UTF8)
$r = Get-MethodRange $deviceText ".method public static setScreenPowerMode(I)Z"
$deviceText = $deviceText.Substring(0, $r.Start) + (Read-Fragment "06-setScreenPowerMode.smali") + $deviceText.Substring($r.End)
[IO.File]::WriteAllText($deviceTarget, $deviceText, $utf8NoBom)

# 7) 新增 DisplayControl 包装类。
$displayControlTarget = Join-Path $SmaliDir "ink\anl\wrappers\DisplayControl.smali"
Copy-Item (Join-Path $PatchDir "07-DisplayControl.smali") $displayControlTarget -Force

# 8) SurfaceControl 新版本中可能已恢复的物理显示方法。
$surfaceControlText = [IO.File]::ReadAllText($surfaceControlTarget, [Text.Encoding]::UTF8)
$powerFieldAnchor = ".field private static setDisplayPowerModeMethod:Ljava/lang/reflect/Method;"
if ($surfaceControlText.IndexOf($powerFieldAnchor) -lt 0) { throw "SurfaceControl 缺少 setDisplayPowerModeMethod 字段锚点" }
if ($surfaceControlText -notmatch "getPhysicalDisplayIdsMethod:") {
    $powerFields = $powerFieldAnchor + $nl + $nl +
        ".field private static getPhysicalDisplayIdsMethod:Ljava/lang/reflect/Method;" + $nl + $nl +
        ".field private static getPhysicalDisplayTokenMethod:Ljava/lang/reflect/Method;"
    $surfaceControlText = $surfaceControlText.Replace($powerFieldAnchor, $powerFields)
}
if ($surfaceControlText -notmatch "\.method public static hasPhysicalDisplayIdsMethod\(\)Z") {
    $surfaceControlText = $surfaceControlText.TrimEnd() + $nl + $nl + (Read-Fragment "08-SurfaceControlPower.smali")
}
[IO.File]::WriteAllText($surfaceControlTarget, $surfaceControlText, $utf8NoBom)

Write-Host ("已打补丁: " + $target) -ForegroundColor Green
Write-Host ("已打补丁: " + $deviceTarget + " (+ DisplayControl)") -ForegroundColor Green
Write-Host ("已打补丁: " + $surfaceControlTarget) -ForegroundColor Green
