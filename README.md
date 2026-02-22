# InputAutoSwitcher（macOS）

一个最小可用的 macOS 菜单栏应用：当前台应用切换时，自动切换输入法。

## 功能

- 监听前台应用变化（`NSWorkspace.didActivateApplicationNotification`）
- 按配置将应用映射到输入法（设置页下拉直接选择，无需手填 ID）
- 通过 `TISSelectInputSource` 执行切换
- 使用 `UserDefaults` 持久化映射配置

## 运行方式

1. 用 Xcode 打开 `/Users/songzihan/Documents/New project/Package.swift`
2. 选择 `InputAutoSwitcher` scheme
3. 运行（`Cmd + R`）
4. 点击菜单栏图标 `输入法切换` 打开设置

也可以在终端编译：

```bash
swift build
```

## 配置映射

在设置页中，每行可直接选择：

- 应用（自动扫描已安装 App）
- 输入法（自动读取系统可用输入法）

可使用 `按当前应用新增` 快速从当前上下文创建规则。

## 常见输入法 Source ID

- `com.apple.keylayout.ABC`（英文）
- `com.apple.inputmethod.SCIM.ITABC`（简体拼音）

实际 ID 取决于你机器上已安装的输入法。

## 云端构建（免本机 Xcode）

本项目已包含 GitHub Actions 工作流：

- `/Users/songzihan/Documents/输入法APP制作/.github/workflows/build-macos-app.yml`

触发方式：

1. 推送到 `main` 分支
2. 或在 GitHub Actions 页面手动触发 `Build macOS App`

构建完成后，在该次运行的 `Artifacts` 下载：

- `InputAutoSwitcher-macos-app`（内含 `InputAutoSwitcher.app.zip`）
