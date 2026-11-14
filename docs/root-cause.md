# 根因分析：AnLink 为什么在 Android 14 上挂掉

本文记录定位过程与证据，方便后续 Android 版本再出问题时按同样路径排查。

## 1. 先看 AnLink 怎么跟手机通信

AnLink 是 Delphi 写的 Windows 端（`AnLink.exe`，VCL，界面类 `FMTMainForm`），
它只做三件事：驱动 adb、接收视频流、发送控制消息。

adb 用的是自带的 `ald.exe`（`Android Debug Bridge version 1.0.41 / 33.0.1`，2022-05-20 构建）。

在 `AnLink.exe` 的 UTF-16 字符串里能找到服务端启动命令：

```
shell CLASSPATH=/data/local/tmp/an-link.jar app_process / ink.anl.Server
max_size=%s bit_rate=%d000000 max_fps=%s tunnel_forward=%s display_id=0 show_touches=false stay_awake=%s %s
```

以及隧道建立方式：

```
adb forward tcp:PORT localabstract:anlink
adb forward --remove tcp:PORT
```

## 2. an-link 是什么

安装目录里的 `an-link`（40 KB）没有扩展名，实际上是一个 zip：

```
$ python -c "import zipfile;print(zipfile.ZipFile('an-link').namelist())"
['classes.dex']            # 86276 字节，dex 035
```

dex 里有 63 个类，包名 `ink.anl`（dex 描述符写作 `Link/anl/...`，前面的 `L` 是类型标记）：

```
ink.anl.Server
ink.anl.ScreenEncoder
ink.anl.Device / DesktopConnection / Controller
ink.anl.Settings
ink.anl.wrappers.SurfaceControl / DisplayManager / InputManager / ServiceManager / ActivityManager / ...
```

这份类结构和 scrcpy **1.25** 几乎一一对应（`Workarounds`、`DesktopConnection`、`DeviceMessage`、
`wrappers/*` 都是 1.25 才有的拆包方式），可以确定 AnLink 的 Android 端是 scrcpy 1.25 的改名分支。

## 3. 失败点

`ink.anl.ScreenEncoder.internalStreamScreen()` 的调用顺序（baksmali 反汇编）：

```
createDisplay()                       -> SurfaceControl.createDisplay("anlink", secure)
createCodec(encoderName)
createFormat(bitRate, maxFps, codecOptions)
configure(codec, format)
surface = codec.createInputSurface()
setDisplaySurface(display, surface, rotation, contentRect, videoRect, layerStack)
codec.start() / encode() / codec.stop()
destroyDisplay(display)
```

而 `setDisplaySurface` 内部是标准的 scrcpy 1.x 事务写法：

```
SurfaceControl.openTransaction()
SurfaceControl.setDisplaySurface(display, surface)
SurfaceControl.setDisplayProjection(display, rotation, deviceRect, displayRect)
SurfaceControl.setDisplayLayerStack(display, layerStack)
SurfaceControl.closeTransaction()
```

`ink.anl.wrappers.SurfaceControl` 全程走反射：

```java
Class<?> CLASS = Class.forName("android.view.SurfaceControl");
CLASS.getMethod("createDisplay", String.class, Boolean.TYPE).invoke(null, name, secure);
```

**Android 14 (API 34) 把这批静态显示事务 API 移除了**，反射直接 `NoSuchMethodException`，
包装类里没有兜底（`catch` 后统一抛 `AssertionError`），于是 `internalStreamScreen` 直接崩，
表现就是「连上了但没画面」。

## 4. 上游怎么修的

scrcpy 侧同样是这个病，issue #4467 记录得很清楚（2023-12 关闭，rom1v 回复 *Fixed in 2.3.1*）。
上游的做法是**换 API**：不再自己造 display，而是让系统帮忙建一个镜像指定 display 的虚拟显示：

```java
// DisplayManager.createVirtualDisplay(String name, int width, int height,
//                                     int displayIdToMirror, Surface surface)
VirtualDisplay vd = (VirtualDisplay) android.hardware.display.DisplayManager.class
        .getMethod("createVirtualDisplay", String.class, int.class, int.class, int.class, Surface.class)
        .invoke(null, "scrcpy", width, height, displayId, encoderSurface);
```

并且保留 `SurfaceControl` 作为 fallback（见 scrcpy master 的 `ScreenCapture.start()`）。

## 5. 本补丁怎么落

AnLink 的 server 没有源码，所以直接改 dex 字节码，改动控制在 `ink.anl.ScreenEncoder`：

| 方法 | 改动 |
|---|---|
| `createDisplay()` | `SDK_INT >= 34` 时返回 `null`，其余版本转调原逻辑（保留为 `createDisplayLegacy()`） |
| `setDisplaySurface(...)` | 收到 `null` 时走 `DisplayManager.createVirtualDisplay`，异常则回退老路径 |
| `destroyDisplay(...)` | `null` 时 `VirtualDisplay.release()`，否则原样 `SurfaceControl.destroyDisplay` |
| `createVirtualDisplay(Surface, Rect)` | 新增，反射调用上面的 5 参静态方法 |

选择在 `setDisplaySurface` 里做分流，是因为这个方法的参数里同时有 **编码器 Surface** 和 **目标尺寸**，
正好满足 `createVirtualDisplay` 的入参要求，不用改动 `internalStreamScreen` 的寄存器流转和 try/catch 结构。

细节见 [patch-diff.md](patch-diff.md)。

## 6. 为什么息屏控制也失效

投屏恢复以后，AnLink 的普通触控已经工作，但“息屏”仍无效。控制消息这一层没有问题：

- 桌面端发送 `ControlMessage.TYPE_SET_SCREEN_POWER_MODE`
- `Controller.handleEvent()` 正确解析出 `POWER_MODE_OFF`
- 随后调用 `Device.setScreenPowerMode(0)`

问题在 `Device.setScreenPowerMode()` 的最后一步：

```java
IBinder display = SurfaceControl.getBuiltInDisplay();
SurfaceControl.setDisplayPowerMode(display, mode);
```

Android 10+ 的 `getBuiltInDisplay()` 实际转调
`SurfaceControl.getInternalDisplayToken()`。Android 14 将物理显示的
`getPhysicalDisplayIds()` / `getPhysicalDisplayToken(long)` 移到了
`com.android.server.display.DisplayControl`，原调用返回 null 或不可用 token，
电源模式设置失败。

scrcpy 2.3.1 的修法是：在 Android 14+ 中从完整的 `SYSTEMSERVERCLASSPATH` 加载
`DisplayControl`，枚举所有物理显示，再逐个调用
`SurfaceControl.setDisplayPowerMode(token, mode)`。补丁移植了该路径，并保留
旧实现作为 ROM 兼容回退。

实际移植时有三个容易全部命中的错误，已在 v1.2 修正：

1. 版本分支曾写成 `if-ge SDK, 34, :legacy`，导致 Android 14/15 反而进入旧路径；
2. 物理显示数组的非空判断曾写成 `if-nez`，导致列表非空时错误跳回旧路径；
3. 类路径分支曾错误地落到 `/system/framework/services.jar`，截断了厂商服务路径。
   魅族把 `com.android.server.DeviceControlService` 放在
   `/apex/com.flyme.runtime/javalib/service-flyme.jar`，截断
   `SYSTEMSERVERCLASSPATH` 会让 `android_servers` 的 JNI 初始化直接 abort。

最终实现使用 `android.system.Os.getenv()` 读取完整类路径，先显式加载
`DeviceControlService`，再从该类的 ClassLoader 加载 `android_servers`。

这与 scrcpy 的息屏语义一致：只关闭物理屏幕面板，不暂停主显示的渲染和输入分发，
所以电脑端仍能看到画面并继续操作手机。

## 7. 验证方法

补丁后的服务端会在 stderr 打一行：

```
anlink-display: created virtual display via DisplayManager.createVirtualDisplay
```

手动复现（手机已连、adb 可用）：

```powershell
$adb = "$env:APPDATA\AnLink\ald.exe"   # 或安装目录里的 ald.exe
& $adb push an-link /data/local/tmp/an-link.jar
& $adb shell chmod 644 /data/local/tmp/an-link.jar
& $adb shell "CLASSPATH=/data/local/tmp/an-link.jar app_process / ink.anl.Server max_size=0 bit_rate=8000000 max_fps=0 tunnel_forward=true display_id=0 show_touches=false stay_awake=false"
```

正常时会先输出 1 字节 `0x00` + 64 字节设备名，随后是 H.264 码流；异常时会有 Java 堆栈。

息屏路径如果成功，`setScreenPowerMode()` 会对每个物理显示返回成功；失败时 stderr
会包含 `Could not initialize DisplayControl`、`Could not get physical display ids`
或 `Could not get physical display token`。
