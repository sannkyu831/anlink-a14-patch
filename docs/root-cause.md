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

## 6. 验证方法

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
