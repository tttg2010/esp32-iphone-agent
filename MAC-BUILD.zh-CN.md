# Mac 端编译 iPhone App 指南（ESP32-S3-N16R8 + ESP32 iPhone Agent）

> 板子那边已经全部就绪（固件已刷入、HID 键鼠 + BLE + AirPlay 接收端都已验证）。
> 你只需要在 Mac 上把 iPhone App 编译安装一次，之后日常使用不需要 Mac。

工程信息：部署目标 **iOS 18.0**，SwiftUI，`.xcodeproj` 已随仓库提交（**不需要** XcodeGen），签名走 `ios/Config/Local.xcconfig`。

---

## 0. 准备清单

| 项目 | 要求 |
|---|---|
| Mac | 装 **Xcode 16 或更新**（App Store 免费）；首次打开要装 iOS 平台组件 |
| iPhone | **iOS 18+**，能装 App（免费 Apple ID 即可） |
| 数据线 | USB-C 机型直连；Lightning 机型需要 Lightning 转 USB 相机转换器（板子由手机供电） |
| 手机网络 | **必须有蜂窝数据**——加板子热点后 Wi-Fi 没外网，模型请求走流量 |
| 模型 API | 任意 OpenAI 兼容的**视觉模型**（能看图），例如你的 `https://www.salpx.com/v1` |

---

## 1. 把代码拿到 Mac

**方式 A（推荐，直连 GitHub）**
```bash
git clone https://github.com/onehumanbeing/esp32-iphone-agent.git
```

**方式 B（国内网络不通时，走镜像）**
```bash
git clone https://ghfast.top/https://github.com/onehumanbeing/esp32-iphone-agent.git
```

**方式 C（用我打好的压缩包）**
把 `esp32-iphone-agent-src.zip`（已排除 .git 和构建产物）拷到 Mac，解压即可。

---

## 2. 配置签名信息（1 分钟）

```bash
cd esp32-iphone-agent/ios
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

编辑 `Config/Local.xcconfig`：

```ini
# 你的 Team ID：Xcode → Settings → Accounts → 选中 Apple ID 就能看到（10 位）
DEVELOPMENT_TEAM = ABCDE12345

# 自己的 bundle id，必须唯一，建议带上你的名字
IA_BUNDLE_ID = com.yourname.esp32agent

# 免费账号没有 App Group / Hotspot Configuration 能力 → 这两行保持留空
IA_ENTITLEMENTS =
IA_WIDGET_ENTITLEMENTS =
```

> 留空的代价：① 不能一键加入板子热点（App 会显示热点密码，手动输）；② 灵动岛/小组件共享不了数据。
> 有付费开发者账号的话，把这两行填成 `IPhoneAgent/IPhoneAgent.entitlements` 和 `AgentActivity/AgentActivity.entitlements`。

---

## 3. 编译安装到 iPhone

1. ```bash
   open ios/IPhoneAgent.xcodeproj
   ```
2. Xcode 顶部选择 **IPhoneAgent** scheme + 你的 iPhone（先插线）。
3. 选中 **IPhoneAgent** target → *Signing & Capabilities* → Team 选你的 Apple ID；
   **再选中 AgentActivity target → 同样选一次 Team**（小组件扩展是独立 target，漏了会报签名错误）。
4. 按 **⌘R** 运行。
5. 手机上首次会拦两道：
   - **开发者模式**：设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启手机
   - **信任证书**：设置 → 通用 → VPN与设备管理 → 你的 Apple ID → 信任

> 免费 Apple ID：签名 **7 天过期**，过期后 App 打不开。届时 Mac 上重新 ⌘R 一次即可（不用删 App）。
> 顺带一提：免费账号 7 天内最多签 3 个 App，够用。

---

## 4. App 内四步引导（每步 App 自己检测）

板子插在 iPhone 上，打开 **ESP32 Agent**：

1. **Plug Me In** — 蓝牙配对板子（名字 `ESP32 Agent XXXX`）。
   扫描限时 12 秒、连接限时 30 秒；连不上点 **Scan Again**。
   ⚠️ 信号弱（RSSI < -90 dBm）会频繁超时，**把板子靠近手机**，或避开 USB 3.0 干扰源。
2. **Let Me See the Screen** — App 显示热点名 `ESP32Agent-XXXX` 和密码。
   设置 → Wi-Fi → 手动加入该热点 → 控制中心 → **屏幕镜像** → 选 **ESP32 Agent**。
3. **Let Me Use the Pointer** — 设置 → 辅助功能 → 触控 → **辅助触控** → 打开。App 会自动校准指针。
4. **Give Me a Brain** — 填模型：
   - Base URL：`https://www.salpx.com/v1`（其它兼容服务同理，注意要带 `/v1`）
   - API Key：你的密钥（存在钥匙串）
   - 模型：从列表里选一个**支持图片输入**的；规划器和执行器可以分别指定
   - App 会发一张生成的彩色图做连通性测试——只有能识图的模型才会通过

---

## 5. 开始用

输入目标（例如「打开设置，进入无线局域网」）→ **Start**。
- 灵动岛显示实时进度，随时可停；
- 每次运行都存了回放（点按/滑动会画在截图上），可以逐步复盘；
- 支持 Siri、快捷指令、小组件触发已保存的任务。

---

## 6. 故障排查

| 症状 | 原因 / 解决 |
|---|---|
| 签名报错 / 装不上 | 两个 target 都要选 Team；`IA_BUNDLE_ID` 改成全网唯一的 |
| 扫描不到板子 | 板子被别的 App 占用（关掉旧版 App）；或离太远，靠近再试 |
| 屏幕镜像里没有 ESP32 Agent | 确认手机已加入 `ESP32Agent-XXXX` 热点；确认板子活着（串口 `ping` 回 `ok`） |
| 镜像有了但点击没反应 | 辅助触控没开，或指针没校准 → 回 Setup 重做第 3 步 |
| 模型连接测试失败 | Base URL 少了 `/v1`；模型不支持图片；云端接口必须 https |
| 手机加入热点后模型请求失败 | 手机没有蜂窝数据 / 没开数据漫游 |
| 用了几天突然打不开 App | 免费签名 7 天过期，Mac 上重新 ⌘R |

---

## 7. 运行时的客观限制（作者说明 + 实测）

- 蓝牙带宽约 300–500 kbps → 镜像只有 **480×1040、≤5 fps**，每步操作要几秒（瓶颈在模型）；
- 键盘输入**只支持 ASCII**，中文输入暂不支持；
- 手机 Wi-Fi 被板子热点占用，模型必须走蜂窝数据；
- iOS 不镜像密码输入、Apple Pay、DRM 视频；**锁屏后镜像会停止**；
- 暂不支持横屏 App。

---

## 8. 提示：板子固件不用再动

你现在板子上跑的已经是这个仓库 `main` 分支编译的固件（2026-10-17 编译，1.45 MB）。
如果以后想改固件再刷，回 Windows 机器用 `hardware/flash-win.sh`（详见 `WINDOWS-SETUP.zh-CN.md`）。

⚠️ 唯一注意：**不要**顺手把仓库切到 `legacy`/`v0.1.0` 分支——那个分支的固件和 App 与现在这套**不通用**。
