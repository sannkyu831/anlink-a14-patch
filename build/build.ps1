# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    从本机已安装的 AnLink 3.10 一键构建 Android 14+ 兼容版 an-link，并编译补丁安装器。

.EXAMPLE
    .\build.ps1
    .\build.ps1 -AnLinkDir 'D:\Tools\Anlink' -Setup 'D:\Downloads\AnLinkSetup\AnLinkSetup.exe'
#>
[CmdletBinding()]
param(
    [string]$AnLinkDir,
    [string]$Setup,
    [string]$OutDir = (Join-Path $PSScriptRoot "..\release")
)

$ErrorActionPreference = "Stop"
$root  = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tools = Join-Path $PSScriptRoot ".tools"
$work  = Join-Path $PSScriptRoot ".work"
New-Item -ItemType Directory -Force -Path $tools, $work, $OutDir | Out-Null

function Get-Tool($url, $dest) {
    if (Test-Path $dest) { return }
    Write-Host ("下载 " + [IO.Path]::GetFileName($dest) + " ...")
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# ---------- 1. 工具链 ----------
$jdkZip = Join-Path $tools "jdk17.zip"
Get-Tool "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip" $jdkZip
if (-not (Get-ChildItem $tools -Directory -Filter "jdk-*" -ErrorAction SilentlyContinue)) {
    Write-Host "解压 JDK ..."
    Expand-Archive $jdkZip -DestinationPath $tools -Force
}
$jdk  = (Get-ChildItem $tools -Directory -Filter "jdk-*" | Select-Object -First 1).FullName
$java = Join-Path $jdk "bin\java.exe"

$jars = [ordered]@{
    "baksmali.jar"   = "https://repo1.maven.org/maven2/org/smali/baksmali/2.5.2/baksmali-2.5.2.jar"
    "smali.jar"      = "https://repo1.maven.org/maven2/org/smali/smali/2.5.2/smali-2.5.2.jar"
    "smali-util.jar" = "https://repo1.maven.org/maven2/org/smali/util/2.5.2/util-2.5.2.jar"
    "dexlib2.jar"    = "https://repo1.maven.org/maven2/org/smali/dexlib2/2.5.2/dexlib2-2.5.2.jar"
    "jcommander.jar" = "https://repo1.maven.org/maven2/com/beust/jcommander/1.72/jcommander-1.72.jar"
    "guava.jar"      = "https://repo1.maven.org/maven2/com/google/guava/guava/30.1.1-jre/guava-30.1.1-jre.jar"
    "antlr.jar"      = "https://repo1.maven.org/maven2/org/antlr/antlr-runtime/3.5.2/antlr-runtime-3.5.2.jar"
}
foreach ($k in $jars.Keys) { Get-Tool $jars[$k] (Join-Path $tools $k) }
$cpBak = (@("baksmali.jar","smali-util.jar","dexlib2.jar","jcommander.jar","guava.jar") | ForEach-Object { Join-Path $tools $_ }) -join ";"
$cpSmali = (@("smali.jar","smali-util.jar","dexlib2.jar","jcommander.jar","guava.jar","antlr.jar") | ForEach-Object { Join-Path $tools $_ }) -join ";"

# ---------- 2. 定位 AnLink ----------
if (-not $AnLinkDir) {
    $cands = @((Join-Path $env:APPDATA "AnLink"), (Join-Path $env:LOCALAPPDATA "AnLink"), "D:\Tools\Anlink")
    $AnLinkDir = $cands | Where-Object { Test-Path (Join-Path $_ "an-link") } | Select-Object -First 1
    if (-not $AnLinkDir) {
        $keys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AnLink",
                  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AnLink",
                  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\AnLink")
        foreach ($k in $keys) {
            $v = Get-ItemProperty $k -ErrorAction SilentlyContinue
            if ($v -and $v.DisplayIcon) {
                $exe = ($v.DisplayIcon -replace [char]34, '') -replace ',\s*\d+\s*$', ''
                if (Test-Path $exe) { $AnLinkDir = Split-Path $exe; break }
            }
        }
    }
}
if (-not $AnLinkDir -or -not (Test-Path (Join-Path $AnLinkDir "an-link"))) {
    throw "找不到 AnLink 安装目录，请用 -AnLinkDir 指定。"
}
Write-Host ("AnLink: " + $AnLinkDir) -ForegroundColor Cyan

# ---------- 3. 解出 classes.dex ----------
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $AnLinkDir "an-link"))
$entry = $zip.Entries | Where-Object { $_.Name -eq "classes.dex" } | Select-Object -First 1
if (-not $entry) { $zip.Dispose(); throw "an-link 里没有 classes.dex" }
$dex = Join-Path $work "classes.dex"
[IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dex, $true)
$zip.Dispose()
Write-Host ("dex: " + (Get-Item $dex).Length + " 字节")

# ---------- 4. 反汇编 -> 打补丁 -> 汇编 ----------
$smaliDir = Join-Path $work "smali"
Remove-Item $smaliDir -Recurse -Force -ErrorAction SilentlyContinue
& $java -cp $cpBak org.jf.baksmali.Main d $dex -o $smaliDir
if ($LASTEXITCODE -ne 0) { throw "baksmali 失败" }
& (Join-Path $PSScriptRoot "..\patch\apply-patch.ps1") -SmaliDir $smaliDir -PatchDir (Join-Path $root "patch")
$newDex = Join-Path $work "classes-patched.dex"
Remove-Item $newDex -Force -ErrorAction SilentlyContinue
& $java -cp $cpSmali org.jf.smali.Main a $smaliDir -o $newDex
if ($LASTEXITCODE -ne 0) { throw "smali 汇编失败" }

# ---------- 5. 打包回 an-link ----------
$outJar = Join-Path $work "an-link"
Remove-Item $outJar -Force -ErrorAction SilentlyContinue
$bytes = [IO.File]::ReadAllBytes($newDex)
$fs = [IO.File]::Create($outJar)
$arch = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
$e = $arch.CreateEntry("classes.dex", [IO.Compression.CompressionLevel]::Optimal)
$s = $e.Open(); $s.Write($bytes, 0, $bytes.Length); $s.Dispose()
$arch.Dispose(); $fs.Dispose()
Write-Host ("生成: " + $outJar + " (" + (Get-Item $outJar).Length + " 字节)") -ForegroundColor Green
Copy-Item $outJar (Join-Path $OutDir "an-link") -Force

# ---------- 6. 编译安装器 ----------
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
$cscArgs = @(
    "/nologo", "/target:winexe", "/platform:anycpu", "/optimize+", "/codepage:65001",
    ("/win32icon:" + (Join-Path $root "installer\anlink14.ico")),
    ("/out:" + (Join-Path $OutDir "AnLink-A14-Patch.exe")),
    ("/resource:" + $outJar + ",anlink_payload"),
    "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll",
    "/r:System.IO.Compression.dll", "/r:System.IO.Compression.FileSystem.dll",
    (Join-Path $root "installer\AnLinkA14Setup.cs")
)
if ($Setup -and (Test-Path $Setup)) {
    $cscArgs = @("/nologo", "/target:winexe", "/platform:anycpu", "/optimize+", "/codepage:65001",
        ("/win32icon:" + (Join-Path $root "installer\anlink14.ico")),
        ("/out:" + (Join-Path $OutDir "AnLink-A14-Full.exe")),
        ("/resource:" + $outJar + ",anlink_payload"),
        ("/resource:" + $Setup + ",anlink_setup"),
        "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll",
        "/r:System.IO.Compression.dll", "/r:System.IO.Compression.FileSystem.dll",
        (Join-Path $root "installer\AnLinkA14Setup.cs"))
    Write-Host ("包含官方安装器: " + $Setup)
}
& $csc @cscArgs
if ($LASTEXITCODE -ne 0) { throw "csc 编译失败" }

$installer = if ($Setup -and (Test-Path $Setup)) {
    Join-Path $OutDir "AnLink-A14-Full.exe"
} else {
    Join-Path $OutDir "AnLink-A14-Patch.exe"
}
$hashLines = @($installer, (Join-Path $OutDir "an-link")) | ForEach-Object {
    $hash = (Get-FileHash -Algorithm SHA256 $_).Hash.ToLowerInvariant()
    $hash + "  " + [IO.Path]::GetFileName($_)
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $OutDir "SHA256.txt"), (($hashLines -join [Environment]::NewLine) + [Environment]::NewLine), $utf8NoBom)

Write-Host ""
Write-Host ("完成，产物在: " + $OutDir) -ForegroundColor Green
Get-ChildItem $OutDir | Select-Object Name, Length | Format-Table -AutoSize
