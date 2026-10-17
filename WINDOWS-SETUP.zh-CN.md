# Windows 安装与刷写说明（ESP32-S3-N16R8）

> 状态：✅ 固件已编译并刷入板子，自检通过（USB HID 键鼠 + 串口命令）。
> 剩余步骤只有 iPhone App——需要一台 Mac + Xcode，见第五节。

---

## 一、本机已安装的内容

| 组件 | 版本 / 位置 |
|---|---|
| arduino-cli | 1.5.2 → `C:\Users\admin\tools\arduino-cli\arduino-cli.exe` |
| ESP32 核心 | `esp32:esp32@3.3.12` → `C:\Users\admin\AppData\Local\Arduino15\packages\esp32` |
| NimBLE-Arduino 库 | 2.5.1（zip 安装）→ `C:\Users\admin\Documents\Arduino\libraries\NimBLE-Arduino` |
| 项目源码 | `C:\Users\admin\WorkBuddy\开发板\esp32-iphone-agent`（main 分支浅克隆） |
| ASCII 构建目录 | `C:\Users\admin\esp32-build`（自动使用，见第二节第 2 条） |
| 固件产物 | `esp32-iphone-agent\hardware\build\*.bin`（1.45 MB，占 3MB APP 分区的 46%，RAM 28%） |

---

## 二、本机环境踩过的坑（复现时必读）

1. **github.com 直连被网络阻断**
   - 已把包索引里的下载地址改写为镜像：
     - `github.com/espressif/*` → `https://dl.espressif.cn/github_assets/espressif/*`（实测 20–58 MB/s，国内 CDN）
     - 其它 github 仓库 → `https://ghfast.top/https://github.com/*`（约 400 KB/s）
   - 被改写的文件（均已留备份 `*.bak.orig`）：
     - `C:\Users\admin\AppData\Local\Arduino15\package_index.json`
     - `C:\Users\admin\tools\arduino-cli\esp32_index_mirror.json`（配置里的 additional_urls 指向它）
   - 注意：**不要再执行 `arduino-cli core update-index`**，否则会重新下载官方索引、覆盖掉镜像改写。

2. **中文路径导致链接失败**
   - 路径里的「开发板」会让 GCC 链接器 `ld` 无法写 `.elf`（报 `������...No such file or directory`）。
   - `flash-win.sh` 已自动处理：检测到非 ASCII 路径时，把 `hid_bridge` 源码同步到 `C:\Users\admin\esp32-build` 里编译，再把产物拷回 `hardware\build\`。

3. **沙箱会挂起编译器子进程**
   - 在受限环境下编译时，`cc1plus` 子进程会被挂起（0 CPU / 0 IO），表现为编译卡死。
   - 本机编译需在**非沙箱**的终端里执行。

4. **N16R8 的 FQBN 与官方 XIAO 不同**
   ```
   esp32:esp32:esp32s3:USBMode=default,CDCOnBoot=cdc,FlashSize=16M,PSRAM=opi,PartitionScheme=app3M_fat9M_16MB
   ```
   - 16 MB Flash → `FlashSize=16M`
   - 8 MB **OPI** PSRAM → `PSRAM=opi`
   - 16 MB 没有 `default_16MB` 这个方案，用 `app3M_fat9M_16MB`（3MB APP，和官方 8MB 方案的 APP 空间一致，固件刚好放得下）

5. **原生 USB 口没有自动复位电路**
   - esptool 的 `--before default-reset` / `RTS` 复位对原生 USB 无效，必须**手动进入下载模式**。
   - 刷完后同样要**手动点 RST** 才会运行新固件。

---

## 三、以后如何重新刷写

### 步骤

1. **手动进下载模式**：按住板子上的 `BOOT`（有的板子标 `IO0`）→ 保持按住并点按一下 `RST`（或 `EN`）→ 松开 BOOT。
   （也可以：按住 BOOT → 拔插 USB → 松开 BOOT）
2. 确认串口变了：设备管理器里会出现 `USB JTAG/serial debug unit`，串口通常是新编号（这次是 **COM4**）。
3. 编译 + 上传：
   ```bash
   cd "C:/Users/admin/WorkBuddy/开发板/esp32-iphone-agent"
   bash hardware/flash-win.sh COM4            # 编译并刷写
   bash hardware/flash-win.sh --build-only    # 只编译
   bash hardware/flash-win.sh COM4 --debug    # 带串口调试日志
   ```
4. **刷完点一下 `RST`（或拔插一次 USB）**，让板子运行新固件。

### 备用：直接用 esptool 刷（等同官方上传参数）

```bash
ESP="C:/Users/admin/AppData/Local/Arduino15/packages/esp32/tools/esptool_py/5.3.1/esptool.exe"
CORE="C:/Users/admin/AppData/Local/Arduino15/packages/esp32/hardware/esp32/3.3.12"
cd /c/Users/admin/esp32-build/build
"$ESP" --chip esp32s3 --port COM4 --baud 921600 \
  --before no-reset --after hard-reset write-flash -z \
  --flash-mode keep --flash-freq keep --flash-size keep \
  0x0 hid_bridge.ino.bootloader.bin \
  0x8000 hid_bridge.ino.partitions.bin \
  0xe000 "$CORE/tools/partitions/boot_app0.bin" \
  0x10000 hid_bridge.ino.bin
```

---

## 四、板子当前状态（已自检）

| 项目 | 结果 |
|---|---|
| USB HID | ✅ HID 键盘 / HID 鼠标 / 消费控制（Home 键）均正常枚举 |
| 调试串口 | ✅ COM5（115200，需置位 DTR） |
| 串口命令 | ✅ `1 ping` → `1 ok`；`2 res 480 1040` → `2 ok` |
| 无线热点 | 板子启动后开热点，名称 `ESP32Agent-XXXX`（XXXX 是蓝牙 MAC 后两位） |
| AirPlay 名称 | 手机「屏幕镜像」里显示为 **ESP32 Agent** |
| 蓝牙名称 | `ESP32 Agent XXXX` |

串口自检方法（PowerShell）：

```powershell
$p = New-Object System.IO.Ports.SerialPort('COM5', 115200)
$p.DtrEnable = $true; $p.Open()
$p.Write("1 ping`n"); Start-Sleep -Milliseconds 800
$p.ReadExisting(); $p.Close()
```

---

## 五、下一步：iPhone App（唯一需要 Mac 的环节）

**需要**：一台装了 Xcode 的 Mac（只需编译一次）· iPhone（iOS 18+）· 手机有蜂窝数据 · 任意 OpenAI 兼容的视觉模型 API。

1. 复制配置并填写签名信息：
   ```bash
   cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig
   # 填 DEVELOPMENT_TEAM（Apple ID 的 Team ID）和 IA_BUNDLE_ID（自己的 bundle id）
   ```
2. 打开工程，选真机运行 `IPhoneAgent` scheme：
   ```bash
   open ios/IPhoneAgent.xcodeproj
   ```
   免费 Apple ID 可签名（7 天需重签一次）。一键连热点需要付费账号的 Hotspot Configuration 能力，没有就手动输密码。
3. App 内四步引导（每步 App 自己检测）：
   1. **Plug Me In**：把板子插到 iPhone，蓝牙配对
   2. **Let Me See the Screen**：加入板子热点 → 控制中心 → 屏幕镜像 → 选 `ESP32 Agent`
   3. **Let Me Use the Pointer**：打开辅助触控（AssistiveTouch），App 自动校准指针
   4. **Give Me a Brain**：填模型地址和密钥（存钥匙串）。例如你现有的 `https://www.salpx.com/v1` + 一个支持图片输入的模型
4. 输入目标（如「打开设置，进入无线局域网」）→ Start。灵动岛显示进度，可随时停止。

**没有 Mac 的三个替代方案**
- 借 / 租一台 Mac（或云 Mac：MacinCloud、MacStadium），编译安装一次即可，日常运行不需要 Mac；
- 找朋友用 Xcode 帮你装到手机上（免费账号需 7 天重签）；
- 改用旧版 `legacy` 分支（v0.1.0）：电脑跑 UxPlay + Python 服务端，**需要 Linux/macOS**，Windows 不支持 UxPlay。

---

## 六、已知限制（作者说明）

- 蓝牙约 300–500 kbps，镜像只有 480×1040、≤5 fps，每步操作要几秒（主要耗时在模型）；
- 键盘输入仅支持 ASCII（中文输入未支持）；
- 运行时手机 Wi-Fi 被板子热点占用，模型请求走蜂窝数据；
- iOS 不镜像密码输入、Apple Pay、DRM 视频画面；锁屏后镜像停止；
- 暂不支持横屏 App。
