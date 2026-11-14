# 补丁细节：`ink.anl.ScreenEncoder` 的字节码改动

原始 dex 来自 AnLink 3.10 安装目录里的 `an-link`（一个只含 `classes.dex` 的 zip），dex 035，86276 字节。
处理流程：baksmali 2.5.2 反汇编 → 改 smali → smali 2.5.2 汇编回 dex（87016 字节）→ 压回 `an-link`。
下面是从**最终 dex 再反汇编回来**的结果，可直接对照上游原始 dex。

## 1. 新增静态字段

```smali
.field private static virtualDisplay:Landroid/hardware/display/VirtualDisplay;
```

## 2. `createDisplay()` —— 按 SDK 版本分流

原实现直接调 `SurfaceControl.createDisplay`。现在 34+ 返回 `null`，把「建显示」推迟到拿到编码器 Surface 之后：

```smali
.method private static createDisplay()Landroid/os/IBinder;
    .registers 3

    # Android 14+ : SurfaceControl virtual display creation is broken,
    # defer to the DisplayManager path (handled in setDisplaySurface)
    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v1, 0x22

    if-lt v0, v1, :legacy

    const/4 v0, 0x0

    return-object v0

    :legacy
    invoke-static {}, Link/anl/ScreenEncoder;->createDisplayLegacy()Landroid/os/IBinder;

    move-result-object v0

    return-object v0
.end method
```

## 3. `createDisplayLegacy()` —— 原逻辑原样保留

把原 `createDisplay` 的方法体整体搬过来，一条指令没改，供 33 及以下版本和异常回退使用：

```smali
.method private static createDisplayLegacy()Landroid/os/IBinder;
    .registers 2

    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v1, 0x1e

    if-lt v0, v1, :cond_17

    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I

    if-ne v0, v1, :cond_15

    sget-object v0, Landroid/os/Build$VERSION;->CODENAME:Ljava/lang/String;

    const-string v1, "S"

    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v0

    if-nez v0, :cond_15

    goto :goto_17

    :cond_15
    const/4 v0, 0x0

    goto :goto_18

    :cond_17
    :goto_17
    const/4 v0, 0x1

    :goto_18
    const-string v1, "anlink"

    invoke-static {v1, v0}, Link/anl/wrappers/SurfaceControl;->createDisplay(Ljava/lang/String;Z)Landroid/os/IBinder;

    move-result-object v0

    return-object v0
.end method
```

## 4. 新增 `createVirtualDisplay(Surface, Rect)`

反射调用 `android.hardware.display.DisplayManager.createVirtualDisplay(String,int,int,int,Surface)`，
第 4 个参数固定为 0（镜像主显示），尺寸取传入的 `Rect`（视频输出尺寸），Surface 为编码器输入 Surface：

```smali
.method private static createVirtualDisplay(Landroid/view/Surface;Landroid/graphics/Rect;)Landroid/hardware/display/VirtualDisplay;
    .registers 8

    # DisplayManager.createVirtualDisplay(String name, int width, int height, int displayIdToMirror, Surface surface)

    const-string v0, "android.hardware.display.DisplayManager"

    invoke-static {v0}, Ljava/lang/Class;->forName(Ljava/lang/String;)Ljava/lang/Class;

    move-result-object v0

    const-string v1, "createVirtualDisplay"

    const/4 v2, 0x5

    new-array v2, v2, [Ljava/lang/Class;

    const/4 v3, 0x0

    const-class v4, Ljava/lang/String;

    aput-object v4, v2, v3

    const/4 v3, 0x1

    sget-object v4, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    aput-object v4, v2, v3

    const/4 v3, 0x2

    aput-object v4, v2, v3

    const/4 v3, 0x3

    aput-object v4, v2, v3

    const/4 v3, 0x4

    const-class v4, Landroid/view/Surface;

    aput-object v4, v2, v3

    invoke-virtual {v0, v1, v2}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v0

    const/4 v1, 0x0

    const/4 v2, 0x5

    new-array v2, v2, [Ljava/lang/Object;

    const/4 v3, 0x0

    const-string v4, "anlink"

    aput-object v4, v2, v3

    const/4 v3, 0x1

    invoke-virtual {p1}, Landroid/graphics/Rect;->width()I

    move-result v5

    invoke-static {v5}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v4

    aput-object v4, v2, v3

    const/4 v3, 0x2

    invoke-virtual {p1}, Landroid/graphics/Rect;->height()I

    move-result v5

    invoke-static {v5}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v4

    aput-object v4, v2, v3

    const/4 v3, 0x3

    const/4 v4, 0x0

    invoke-static {v4}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v4

    aput-object v4, v2, v3

    const/4 v3, 0x4

    aput-object p0, v2, v3

    invoke-virtual {v0, v1, v2}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/hardware/display/VirtualDisplay;

    sget-object v1, Ljava/lang/System;->err:Ljava/io/PrintStream;

    const-string v2, "anlink-display: created virtual display via DisplayManager.createVirtualDisplay"

    invoke-virtual {v1, v2}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V

    return-object v0
.end method
```

## 5. `setDisplaySurface(...)` —— 分流 + 回退

`display == null` 表示走 Android 14+ 分支：先建虚拟显示并直接返回；
任何异常（`catchall`）都退回 `createDisplayLegacy()` + 原来的 `SurfaceControl` 事务流程，保证不会比原版更差：

```smali
.method private static setDisplaySurface(Landroid/os/IBinder;Landroid/view/Surface;ILandroid/graphics/Rect;Landroid/graphics/Rect;I)V
    .registers 7

    if-nez p0, :legacy

    :try_start_0
    invoke-static {p1, p4}, Link/anl/ScreenEncoder;->createVirtualDisplay(Landroid/view/Surface;Landroid/graphics/Rect;)Landroid/hardware/display/VirtualDisplay;

    move-result-object v0

    sput-object v0, Link/anl/ScreenEncoder;->virtualDisplay:Landroid/hardware/display/VirtualDisplay;

    return-void
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    :catchall_0
    move-exception v0

    invoke-static {}, Link/anl/ScreenEncoder;->createDisplayLegacy()Landroid/os/IBinder;

    move-result-object p0

    :legacy
    invoke-static {}, Link/anl/wrappers/SurfaceControl;->openTransaction()V

    :try_start_3
    invoke-static {p0, p1}, Link/anl/wrappers/SurfaceControl;->setDisplaySurface(Landroid/os/IBinder;Landroid/view/Surface;)V

    invoke-static {p0, p2, p3, p4}, Link/anl/wrappers/SurfaceControl;->setDisplayProjection(Landroid/os/IBinder;ILandroid/graphics/Rect;Landroid/graphics/Rect;)V

    invoke-static {p0, p5}, Link/anl/wrappers/SurfaceControl;->setDisplayLayerStack(Landroid/os/IBinder;I)V
    :try_end_c
    .catchall {:try_start_3 .. :try_end_c} :catchall_11

    invoke-static {}, Link/anl/wrappers/SurfaceControl;->closeTransaction()V

    nop

    return-void

    :catchall_11
    move-exception p0

    invoke-static {}, Link/anl/wrappers/SurfaceControl;->closeTransaction()V

    throw p0
.end method
```

## 6. `destroyDisplay(...)` —— 对称释放

`display == null` 时释放 `VirtualDisplay`，否则保持原来的 `SurfaceControl.destroyDisplay`：

```smali
.method private static destroyDisplay(Landroid/os/IBinder;)V
    .registers 2

    if-nez p0, :legacy

    sget-object v0, Link/anl/ScreenEncoder;->virtualDisplay:Landroid/hardware/display/VirtualDisplay;

    if-eqz v0, :done

    invoke-virtual {v0}, Landroid/hardware/display/VirtualDisplay;->release()V

    const/4 v0, 0x0

    sput-object v0, Link/anl/ScreenEncoder;->virtualDisplay:Landroid/hardware/display/VirtualDisplay;

    :done
    return-void

    :legacy
    invoke-static {p0}, Link/anl/wrappers/SurfaceControl;->destroyDisplay(Landroid/os/IBinder;)V

    return-void
.end method
```

## 7. 息屏控制：`Device.setScreenPowerMode()` 与 `DisplayControl`

`Controller` 的息屏消息解析无需修改。补丁替换 `Device.setScreenPowerMode(I)Z`，
并给现有 `SurfaceControl` 包装类补上物理显示 ID/token 查询方法。SDK 34+ 优先调用
ROM 中仍存在的 `SurfaceControl.getPhysicalDisplayIds()`；如果 API 已被移走，则通过
新增的 `ink.anl.wrappers.DisplayControl` 枚举物理显示。拿到 token 后逐个调用
`SurfaceControl.setDisplayPowerMode()`；两条路径都拿不到显示列表时回退原单显示路径。

版本判断必须使用 `if-lt vSDK, 34, :legacy`，即只有低于 Android 14 才走旧路径。
物理显示数组的非空判断也必须使用 `if-eqz`；写成 `if-ge` 或 `if-nez` 会让 Android 15
恰好跳进旧路径。

新增包装类的关键部分与 scrcpy 2.3.1+ 相同：

```java
ClassLoader loader = ClassLoaderFactory.createClassLoader(
        Os.getenv("SYSTEMSERVERCLASSPATH"),
        null, null, ClassLoader.getSystemClassLoader(), 0, true, null);
Class<?> displayControl = loader.loadClass("com.android.server.display.DisplayControl");
Class<?> deviceControlService = loader.loadClass("com.android.server.DeviceControlService");
Runtime.getRuntime().loadLibrary0(deviceControlService, "android_servers");
```

必须保留完整的 `SYSTEMSERVERCLASSPATH`，不能简化为
`/system/framework/services.jar`。例如魅族 Android 15 的
`com.android.server.DeviceControlService` 位于
`/apex/com.flyme.runtime/javalib/service-flyme.jar`；只传 `services.jar` 会让
`android_servers` 的 `JNI_OnLoad` 找不到类并直接 abort 进程。

这一加载步骤是必要的，因为 `DisplayControl` 的物理显示方法依赖
`android_servers` 原生库。

`apply-patch.ps1` 同时支持两种输入：

- 官方 `an-link`：应用 DisplayManager 显示补丁和息屏补丁
- 已经安装 v1 显示补丁的 `an-link`：跳过已存在的显示补丁，只补上息屏控制

## 8. 为什么不动 `internalStreamScreen`

`internalStreamScreen` 里有 try/catch 保护和十几个寄存器的流转，改它风险最大。
而 `setDisplaySurface` 的入参恰好已经带了**编码器 Surface** 和**目标 Rect**，
把新逻辑塞进这个方法，主流程一条指令都不用动。
