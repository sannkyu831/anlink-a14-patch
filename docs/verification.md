# v1.2 构建与验证记录

本次息屏补丁的本地验证结果。

## 工具链

- baksmali / smali 2.5.2
- DragonWell JDK 21
- Windows .NET Framework `csc.exe`
- 输入：AnLink 3.10 已安装的 `an-link`（已包含上一版 DisplayManager 投屏补丁）
- 参考实现：scrcpy 2.3.1 与 5.0.1

## 已验证

1. `patch/apply-patch.ps1` 能从已安装 v1 补丁的 `an-link` 继续应用息屏补丁。
2. 对已打补丁的 smali 再执行一次，脚本可重复运行，不会生成重复方法。
3. smali 2.5.2 汇编成功，退出码 0。
4. 生成 dex 再 baksmali 成功，`DisplayControl`、`SurfaceControl` 物理显示方法、
   `Device.setScreenPowerMode()` 均存在且调用关系正确。
5. 最终 `an-link` 压缩包只有一个 `classes.dex` 条目。
6. 安装器用 `csc.exe` 编译成功，内嵌 payload 的 SHA256 与 `release/an-link` 一致。
7. `build/build.ps1 -AnLinkDir D:\Tools\AnLink` 端到端执行成功，并自动同步
   `release/an-link` 与 `release/SHA256.txt`。
8. 安装器能从 `classes.dex` 内识别旧显示补丁，避免把已修补文件错误标记为官方备份。

## Android 15 真机验证

测试设备：MEIZU 21 Pro，Android 15 / SDK 35，serial `481QJFEEPRG9G`。
使用独立控制客户端发送与 AnLink 息屏按钮、`Ctrl+L` 相同的控制消息
`TYPE_SET_SCREEN_POWER_MODE`，先发送 `OFF`，再发送 `ON`。

最终日志：

```text
anlink-power: setScreenPowerMode on Android 14+
anlink-power: using DisplayControl physical displays
anlink-power: DisplayControl initialized
anlink-power: DisplayControl.getPhysicalDisplayIds returned
anlink-power: physical display list found
anlink-power: display power applied
Device screen turned off

anlink-power: display power applied
Device screen turned on
```

没有出现 `VerifyError`、`ClassNotFoundException`、JNI abort 或旧路径
`getInternalDisplayToken` 调用。`dumpsys display` 的 `mScreenState` 仍为 `ON`
是预期行为：这里关闭的是物理显示面板，Android 主显示和虚拟显示继续运行，
所以投屏及输入仍然可用。
