# AX Overlay Studio

基于 DarkSword / lara 内核底座的 iOS App 工程骨架，包含：

- 液体玻璃风格 App UI 与悬浮图标（参考 `apple-visionpro-interaction` 视觉规格）。
- DarkSword `ds_run / ds_kread64 / ds_kwrite64` 内核读写接入层。
- AX 风格跨 App 悬浮链的 SpringBoard 注入接口（vtable 未绑定时返回结构化错误）。
- GitHub Actions 云端编译，输出 unsigned IPA（爱思助手重签）或 development IPA（有证书时）。

## 本地生成工程

需要 macOS + Xcode + XcodeGen：

```bash
brew install xcodegen
xcodegen generate
open AXOverlayStudio.xcodeproj
```

## 云端编译

推送到 GitHub 后，Actions 自动运行 `build.yml`。详细步骤见 [GITHUB_BUILD.md](GITHUB_BUILD.md)。

两条签名路径：

1. **无证书（默认）**：`CODE_SIGNING_ALLOWED=NO` 编译，导出 unsigned IPA，下载后用爱思助手自签安装。
2. **有证书**：配置 Secrets `SIGNING_P12_BASE64` / `SIGNING_P12_PASSWORD` / `PROVISIONING_PROFILE_BASE64` / `TEAM_ID`，`xcodebuild archive + exportArchive` 导出 development IPA。

## 目录

- `Sources/`：AppDelegate、ViewController、Theme、FloatingBallView、FloatingOverlay、KernelBridge、main。
- `CrossApp/`：SpringBoard 注入与野生 UIWindow 接口。
- `DarkSwordIntegration/`：lara `ds_*` API shim。
- `Vendor/lara/`：vendored 的 lara kexploit 源码、头文件、fat dylib（arm64 / arm64e）。
- `.github/workflows/build.yml`：云端编译流水线。

跨 App 悬浮的真实生效依赖 `CrossAppRemoteVTable` 绑定与 SpringBoard 注入链，未绑定时仅本机浮窗可见。
