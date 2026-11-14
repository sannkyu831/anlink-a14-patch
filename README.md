# AnLink Android 14+ 兼容补丁

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D6)
![Android: 14+](https://img.shields.io/badge/Android-14%2B-3DDC84)

让 **AnLink 3.10**（2022 年停更的最后一版）重新能在 **Android 14 / 15 / 16** 上投屏、操作手机，
并支持 AnLink 的**息屏控制**。

> 现状：AnLink 官方 2022-05 之后没有再更新，内置的手机端服务端停留在 scrcpy 1.25 的水平。
> Android 14 移除了它依赖的一批 `SurfaceControl` 虚拟显示 API，所以新手机上「能连上、但黑屏 / 无法操作」。
> 上游 scrcpy 在 2.3.1（2023-12）修了这个问题，但 AnLink 用的是私有 fork（包名被改成 `ink.anl`），
> 没法直接套用新版 server —— 所以有了这个补丁。

## 症状

| 现象 | 说明 |
|---|---|
| 手机能识别、能连上，投屏黑屏或一直转圈 | 虚拟显示创建失败 |
| 有画面但点击/滑动没反应 | 同源问题（显示对象没建起来） |
| 投屏和触控正常，但点击“息屏”后界面没有熄灭 | Android 14 移动了物理显示电源 API |
| Android 13 及以下一切正常 | 老 API 还在 |

## 修复原理

AnLink 启动服务端的方式是固定的：

```
shell CLASSPATH=/data/local/tmp/an-link.jar app_process / ink.anl.Server \
      max_size=.. bit_rate=.. max_fps=.. tunnel_forward=.. display_id=0 show_touches=false stay_awake=..
```

服务端 `ink.anl.ScreenEncoder` 原本走 scrcpy 1.x 的老路：

```java
SurfaceControl.createDisplay("anlink", secure)
SurfaceControl.openTransaction()
SurfaceControl.setDisplaySurface(display, encoderSurface)
SurfaceControl.setDisplayProjection(display, 0, deviceRect, displayRect)
SurfaceControl.setDisplayLayerStack(display, layerStack)
SurfaceControl.closeTransaction()
```

这些静态事务 API 在 **Android 14 (SDK 34)** 被移除，反射拿不到方法 → 抛异常 → 投屏失败。

补丁改成 SDK 34+ 走 `DisplayManager` 通道（与上游 scrcpy 2.x 的做法一致）：

```java
android.hardware.display.DisplayManager
    .createVirtualDisplay("anlink", width, height, displayIdToMirror = 0, encoderSurface)
```

并且保留了完整的回退：新通道调用失败会自动 catch，退回原来的 `SurfaceControl` 路径。
`SDK_INT < 34` 的设备行为与原版逐字节一致，不受影响。

息屏控制是另一条调用链。AnLink 的 `Controller` 已经能正确解析
`TYPE_SET_SCREEN_POWER_MODE`，但旧版 `Device.setScreenPowerMode()` 仍通过
`SurfaceControl.getInternalDisplayToken()` 获取显示，再设置电源模式。
Android 14 把物理显示的枚举和 token 获取移到了系统 `DisplayControl` 类，因此旧路径
拿不到正确对象。

补丁参考 scrcpy 2.3.1+ 的实现，在 SDK 34+ 上优先使用
`SurfaceControl.getPhysicalDisplayIds()`；如果当前 ROM 已把该 API 移走，则：

1. 通过 `android.system.Os.getenv()` 读取完整的 `SYSTEMSERVERCLASSPATH`
2. 用系统 `ClassLoaderFactory` 创建服务端 ClassLoader，加载
   `com.android.server.display.DisplayControl` 和厂商的
   `com.android.server.DeviceControlService`
3. 加载 `android_servers` 原生库，枚举全部物理显示
4. 对每个显示调用仍存在的 `SurfaceControl.setDisplayPowerMode()`
5. 如果 `DisplayControl` 初始化失败，自动回退原单显示路径

这样 AnLink 发出的“息屏”消息仍然作用于真实物理屏幕，同时 Android 主显示继续渲染，
所以投屏画面和鼠标/键盘/触控输入都保持可用。退出 AnLink 时，原有清理逻辑会把屏幕恢复。

## 使用

### 方式一：双击补丁（推荐）

下载 [`AnLink-A14-Patch.exe`](../../releases/latest) → 双击 → 点「安装补丁」。

- 自动定位 AnLink 安装目录（默认路径 / 注册表 `DisplayIcon`、`UninstallString` / 各盘浅扫）
- 找不到时点「手动选择安装目录」
- 自动备份原文件为 `an-link.orig-310`
- 已装旧补丁且没有官方备份时，会保留带时间戳的安全副本，不把旧补丁误标成官方版
- 点「还原官方版本」可回滚

### 方式二：手动替换

1. 关闭 AnLink
2. 备份安装目录里的 `an-link`
3. 用本仓库 `release/` 里的同名文件覆盖
4. 启动 AnLink

> 只改这一个文件。`an-link` 是手机端的 dex 容器（一个 zip，里面只有 `classes.dex`）。

## 支持矩阵

| Android | 状态 |
|---|---|
| 4.x – 13 | 走原有路径，等同原版 |
| 14 / 15 / 16 | 投屏走 `DisplayManager.createVirtualDisplay`；息屏走 `DisplayControl` + 物理显示电源模式 |

## 自己构建

见 [`build/build.ps1`](build/build.ps1)：从你本机已安装的 AnLink 抽出 `an-link` → 解包 dex →
baksmali → 打补丁 → smali 重新汇编 → 打包 → 用 `csc` 编译安装器。

工具链（脚本会自动下载）：JDK、baksmali/smali 2.5.2。

## 已知限制

- AnLink 已经停更，未来 Android 大版本若再改动相关 API，需要再做一次字节码适配。
- 不同厂商 ROM 的 `DisplayManager` 行为可能略有差异；服务端会把异常打到 stderr，便于定位。
- 厂商 ROM 的系统服务类可能分布在额外的 APEX 服务 jar 中。补丁使用运行时完整
  `SYSTEMSERVERCLASSPATH`，静态使用 `services.jar` 的写法会在魅族等 ROM 上加载失败。
- 不修改 AnLink 主程序，不联网、不收集任何数据。

## 常见问题

### 连接后手机自动熄屏

这是 AnLink 自身设置，不是补丁默认行为。打开 AnLink 设置，关闭
**“连接后熄屏”**；它对应 `settings.cfg` 中的
`connection.turnoff`。关闭后连接会保持亮屏，手动点击“息屏”或按 `Ctrl+L`
仍然可以正常熄屏。

## 参考

- scrcpy issue #4467 — *Doesn't work after upgrading to Android 14*（rom1v: Fixed in 2.3.1）
- scrcpy #4656 / #4657 — 后续固件上的同类问题
- 上游实现：`server/.../video/ScreenCapture.java`（优先 DisplayManager，失败回退 SurfaceControl）
- 息屏实现：`server/.../device/Device.java`、`server/.../wrappers/DisplayControl.java`

## 许可

补丁代码以 MIT 发布；AnLink 本体版权归其作者所有，本仓库不包含任何官方安装包。
详见 [NOTICE.md](NOTICE.md)。
