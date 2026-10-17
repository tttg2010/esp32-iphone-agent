# 方案 B：用 GitHub Actions 云编译 IPA（不需要本地 Mac / Xcode）

> 思路：GitHub 的 macOS runner 帮你做**无签名**构建，输出 `.ipa`；
> 再在 Windows 上用 **Sideloadly** + 免费 Apple ID 把它签好装进手机。
> 一次配好，以后每次改完代码点一下就能拿到新的 ipa。

工作流已放在 `.github/workflows/ios-unsigned-ipa.yml`（我已加到本地提交里）。

---

## 一、把代码推到你的 GitHub

### 1. 建仓库
GitHub 右上角 **+ → New repository**：
- Repository name：`esp32-iphone-agent`
- 可见性选 **Public**（public 仓库的 macOS runner 分钟数免费；私有仓库也够用，只是走共享额度）
- **不要**勾选 "Add a README"（避免和本地冲突）

### 2. 本地 push（在 Windows 这台机器上）

```bash
cd "C:/Users/admin/WorkBuddy/开发板/esp32-iphone-agent"
git remote set-url origin https://github.com/你的用户名/esp32-iphone-agent.git

# 先看一眼提交里有什么（我已经把工作流和文档提交好了）
git log --oneline -1
git show --stat --oneline HEAD

git push -u origin main
```

密码那一步不能再用账号密码，要用 **Personal Access Token**：
GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token，勾 `repo` 权限，用它当密码。

> 推不上去的常见原因：国内直连 GitHub。可选：① 开代理后 `git config --global http.proxy http://127.0.0.1:端口`；
> ② 改用 SSH over 443；③ 干脆在网页上传（把整个仓库打包成 zip 拖进 GitHub 也可以，但会丢提交历史）。

---

## 二、跑工作流，拿 ipa

1. 打开仓库页 → **Actions** 标签
   - 如果是 fork 来的仓库，会提示 Actions 被禁用 → 点 **"I understand my workflows, go ahead and enable them"**
2. 左侧选 **iOS unsigned IPA** → 右侧 **Run workflow** → 选 `main` → Run
3. 等 **3–6 分钟**（第一次会久一点，要装 iOS 平台组件）
4. 构建成功后，进这次 run → 底部 **Artifacts** → 下载 `ESP32Agent-unsigned-ipa.zip` → 解压得到 **`ESP32Agent-unsigned.ipa`**

构建失败时先看 `Build (unsigned, device)` 这一步的日志；如果报 `requires a development team`，说明签名没关干净（本工作流已带 `CODE_SIGNING_ALLOWED=NO`，正常不会出现）。

---

## 三、Windows 上装进 iPhone（Sideloadly）

### 准备（一次性）
1. **Apple 设备驱动**：Microsoft Store 搜「Apple 设备」安装（或装 iTunes）。没有它 Windows 认不到 iPhone。
2. **Sideloadly**：官网 <https://sideloadly.io> 下载 Windows 版（免费）。
3. **iPhone**：
   - iOS 16+ 需要打开 **设置 → 隐私与安全性 → 开发者模式**（打开后要重启）
   - 用数据线连电脑，手机上点「信任此电脑」

### 安装
1. 以管理员身份打开 **Sideloadly**
2. 顶部 **iOS device** 选到你的 iPhone
3. 把 `ESP32Agent-unsigned.ipa` 拖进 **IPA** 框
4. **Apple account** 填你的 Apple ID（免费账号即可）
5. 需要的话改 **Bundle ID**（比如 `com.yourname.esp32agent`，要和已装的其他 App 不冲突）
6. 点 **Start** → 输入 Apple ID 密码（Sideloadly 用本地 anisette 做验证，不会上传你的密码）→ 等进度条走完

### 装完还要做一步
手机上：**设置 → 通用 → VPN与设备管理 → 开发者 App → 你的 Apple ID → 信任**
然后回桌面点开 **ESP32 Agent**，第一次会弹**蓝牙权限**，选允许。

---

## 四、免费账号 7 天重签

免费 Apple ID 的签名 **7 天过期**，过期后 App 点开就闪退。

| 方式 | 说明 |
|---|---|
| **手动重签（最简单）** | 7 天后重复上面「安装」步骤，2 分钟，**不用删 App**，直接覆盖安装 |
| **自动续签** | 装 **AltStore**：Windows 上跑 AltServer 常驻 + 手机同 Wi-Fi，会自动在后台续签。代价是免费账号只能挂 3 个 App |
| **付费账号（$99/年）** | 一次签一年，还能用一键连热点（Hotspot Configuration）和灵动岛共享 |

> 我已经给你挂了个每周提醒（每周六 20:00），到点会提示重签，别嫌烦，可以随时让我改或删。

---

## 五、常见问题

| 症状 | 原因 / 解决 |
|---|---|
| Actions 里没有 “Run workflow” 按钮 | 工作流文件不在默认分支（`main`）上；或 fork 的 Actions 未启用 |
| `xcodebuild: error: SDK "iphoneos" cannot be located` | runner 的 Xcode 版本问题，把 `runs-on` 换成 `macos-latest` 或 `macos-15` |
| `YOUR_APP requires a development team` | 签名没关干净，确认 `CODE_SIGNING_ALLOWED=NO` 生效（本仓库已内置） |
| Sideloadly 认不到设备 | 没装「Apple 设备」驱动；或数据线只能充电；换线/换口，重插并点手机上「信任」 |
| Sideloadly 报 bundle id 冲突 | 改一个唯一的 Bundle ID 再签 |
| 装上了点开闪退 | ① 没信任开发者证书；② 签名过期（7 天）；③ 手机 iOS < 18 |
| 装上了但设置里连不上板子 | 蓝牙权限没给；或板子太远（RSSI < -90dBm 会超时） |

---

## 六、和「Mac 直接编」怎么选

| | 本方案（GitHub Actions） | Mac 直接编（见 `MAC-BUILD.zh-CN.md`） |
|---|---|---|
| 需要 Mac | ❌ 不需要 | ✅ 需要（Xcode 16+） |
| 第一次上手 | 要配仓库 + 等 CI（约 20 分钟） | 打开 Xcode 就能跑（约 10 分钟） |
| 之后改代码 | push 一下就出新 ipa | 每次都要 Mac 上 ⌘R |
| 调试体验 | 看不到控制台/断点 | 完整调试器、日志、SwiftUI 预览 |
| 适合 | 只想装一次用起来、或想在多台手机装 | 要改 App 代码、要看日志排查 |

**结论**：你有 Mac，想改代码就用 Mac 那条；只想拿个能用的 App，就走这条 CI 路线。
