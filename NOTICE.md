# NOTICE

## 与 AnLink 官方的关系

本仓库是**第三方兼容性补丁**，与 AnLink 作者无关，也未经其授权。

- AnLink（含 `AnLink.exe`、`an-link`、`ald.exe` 等）版权归 AnLink 作者所有。
- 本仓库**不包含** AnLink 官方安装包，也不分发完整安装目录。
- `release/AnLink-A14-Patch.exe` 内嵌的 `an-link` 是基于用户本机已安装的 AnLink 3.10 修改得到的衍生文件，
  仅包含使 AnLink 在 Android 14+ 上正常工作的必要改动（`ink.anl.ScreenEncoder` 的显示创建路径，
  以及 `ink.anl.Device` / `ink.anl.wrappers.DisplayControl` 的息屏控制路径）。

## 使用前提

使用本补丁前，你应当已经合法持有 AnLink 3.10。补丁不提供、不绕过任何授权机制，
也不修改 AnLink 的界面、付费/激活逻辑或联网行为。

## 来源与致谢

修复思路来自 scrcpy 上游（Genymobile/scrcpy）：

- issue #4467 — *Doesn't work after upgrading to Android 14*（Fixed in 2.3.1）
- issue #4656 / pull #4657 — 后续固件上的同类问题
- 实现参考：`server/src/main/java/com/genymobile/scrcpy/video/ScreenCapture.java`
- 息屏参考：`server/src/main/java/com/genymobile/scrcpy/device/Device.java`、
  `server/src/main/java/com/genymobile/scrcpy/wrappers/DisplayControl.java`

scrcpy 以 Apache-2.0 许可发布。本仓库的 `DisplayControl` 兼容包装类是对其公开
系统类加载与物理显示 API 用法的 smali 适配；相关实现仍受 Apache-2.0 约束。

## 许可

本仓库中由本项目编写的代码（安装器、构建脚本、文档）以 MIT 发布，见 [LICENSE](LICENSE)。
