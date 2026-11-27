# GitHub Actions 云端编译指南

本机 Windows 无 Xcode、无证书，用 GitHub 免费 macOS runner 编译出 IPA，再由爱思助手重签安装。两条路径：无证书走 unsigned，有证书走 development signed。

## 1. 推送仓库

```powershell
cd "E:\04_WorkBuddy\WorkBuddy_PoJie\ipa-破解\AX Pro Max_1.5.3.ipa\_re\github_repo"
git init
git add .
git commit -m "AX Overlay Studio: GitHub Actions build"
git remote add origin https://github.com/<你的账号>/<你的仓库>.git
git push -u origin main
```

推送后进入 GitHub 仓库 → Actions → `Build AX Overlay Studio IPA` → Run workflow。

`build.yml` 同时绑定 `push` 到 main/master，每次推送都会触发。

## 2. 无证书路径（默认，推荐先用这条）

不配置任何 Secrets，workflow 检测到签名材料缺失，自动走 unsigned：

1. `brew install xcodegen` → `xcodegen generate`。
2. `xcodebuild ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO clean build`。
3. `scripts/make_unsigned_ipa.py` 把 `.app` 包成 unsigned IPA。
4. Artifacts 下载 `AXOverlayStudio_unsigned`，解压得到 `AXOverlayStudio_unsigned.ipa`。

下载后用爱思助手「应用 → 导入 IPA → 签名安装」重签。安装后到 设置 → 通用 → VPN与设备管理 信任企业证书。

注意：这个 unsigned IPA 里的 `libxpf.dylib` / `libgrabkernel2.dylib` 是 fat 双切片（arm64 / arm64e），爱思重签会连同 dylib 一起签。

## 3. 有证书路径（Development 签名）

在 仓库 → Settings → Secrets and variables → Actions → New repository secret 添加：

| Secret 名 | 值 | 获取方式 |
| --- | --- | --- |
| `SIGNING_P12_BASE64` | p12 的 base64 | Mac 钥匙串导出「登录 → 我的证书 → Development 证书 → 导出 .p12」，然后 `base64 -i cert.p12 \| tr -d '\n'` |
| `SIGNING_P12_PASSWORD` | p12 导入密码 | 导出时设置的密码 |
| `PROVISIONING_PROFILE_BASE64` | mobileprovision 的 base64 | Apple Developer 下载 Development 描述文件，`base64 -i profile.mobileprovision \| tr -d '\n'` |
| `TEAM_ID` | 10 位 Team ID | Apple Developer 账户页 |

可选 Variables（不是 secret）：

| Variable 名 | 默认值 | 说明 |
| --- | --- | --- |
| `BUNDLE_ID` | `com.yourteam.axoverlay` | 必须与描述文件 App ID 一致（不要用它保留的 `com.apple.*`） |

四个 secret 齐全后，workflow 自动切到 signed：

1. 创建临时 keychain，导入 p12。
2. 解码 mobileprovision，装到 `$HOME/Library/MobileDevice/Provisioning Profiles`。
3. `scripts/gen_export_options.py` 生成 `exportOptions.plist`（method=development）。
4. `xcodebuild archive + exportArchive` 导出 development IPA。
5. Artifacts 下载 `AXOverlayStudio_signed`。

## 4. Bundle ID 注意事项

- 不要用 `com.apple.music` 之类 Apple 保留 ID，临时 keychain 里伪造的 AppID 描述文件会被设备拒绝（错误 `0xe8008015`）。
- Development 描述文件的 App ID 必须与 `BUNDLE_ID` 完全一致；若用 wildcard，设为实际 bundle id。
- entitlements 里目前只有 `get-task-allow=true`，与 development 签名匹配。

## 5. 常见 xcodebuild 错误排查

| 错误 | 原因 | 处理 |
| --- | --- | --- |
| `No signing certificate "iOS Development" found` | p12 不是 Development 证书，或密码错 | 重新导出 p12，确认 `SIGNING_P12_PASSWORD` |
| `A valid provisioning profile for this executable was not found` | Bundle ID 与描述文件不符，或用了保留 ID | 改 `BUNDLE_ID` variable 与描述文件一致 |
| `Code Signing Error: ... has conflicting provisioning settings` | 工程残留签名设置 | workflow 已用 `CODE_SIGN_STYLE=Manual` + `PROVISIONING_PROFILE_SPECIFIER` 覆盖 |
| `ld: library not found for -lxpf` | dylib 未 vendored 路径错 | 确认 `Vendor/lara/lib/libxpf.dylib` 存在，`LIBRARY_SEARCH_PATHS` 含 `$(SRCROOT)/Vendor/lara/lib` |
| `include not found: darksword.h` | Header path 错 | 确认 `HEADER_SEARCH_PATHS` 含 `$(SRCROOT)/Vendor/lara/kexploit` 与 `headers` |
| `xcodegen: command not found` | brew 安装失败 | workflow 里已 `brew install xcodegen`，本地可 `brew install xcodegen` |
| `Unable to find a destination matching generic/platform=iOS` | Xcode 版本缺 iOS SDK | `sudo xcode-select` 指向带 iOS SDK 的 Xcode |

## 6. 跨 App 悬浮的运行时边界

云端编译只能产出 App UI 与悬浮图标骨架。跨 App 悬浮要真正生效，必须：

1. 绑定 `CrossAppRemoteVTable`（`CrossApp/CrossAppOverlayController.h`）。
2. `KernelBridge` 里绑定 `remoteInvocationBlock` 到 lara `TaskRop/RemoteCall.m` 的远程调用。
3. 设备跑 `ds_run` 起内核权限后，在 SpringBoard 进程内创建野生 `UIWindow`，level = `10000000.0`。

未绑定时 `installCrossAppOverlayWithWindowLevel:error:` 返回 `CrossAppErrorUnavailable`，浮窗只在自身 App 沙盒内。
