<p align="center">
  <img src="Hakoniwa/Assets.xcassets/AppIcon.appiconset/app_icon_128@2x.png" width="128" height="128" alt="Hakoniwa Icon" />
</p>

<h1 align="center">Hakoniwa (箱庭)</h1>

<p align="center">
  <strong>原生 macOS 3D 像素艺术动态壁纸与交互沙盘</strong><br>
  <em>Native macOS 3D Pixel Art Live Wallpaper & Interactive Desktop Toy</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?style=flat-square&logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/Language-Swift%205.9%2B-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2F%20AppKit-indigo?style=flat-square" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Renderer-CPU%20Software%20Rasterizer-green?style=flat-square" alt="Renderer" />
  <img src="https://img.shields.io/badge/License-MIT-teal?style=flat-square" alt="License" />
</p>

---

## 📖 简介 (Overview)

**Hakoniwa (箱庭)** 是一款为 macOS 深度定制的 3D 像素艺术沙盘与桌面玩具。它既可以作为一个小巧雅致的独立窗口应用运行，也能沉浸式化身为 macOS 桌面底层动态壁纸，在不影响日常生产力工作的同时，为你的桌面增添一份复古与生机。

项目摒弃了重量级三方商业游戏引擎，采用纯原生 **Swift + AppKit / SwiftUI** 与 **SIMD** 硬件加速，自研轻量级 30° 等轴测软光栅（Software Rasterizer）。兼具极致的高保真复古像素美感与极低的 CPU、内存和电池能耗。

---

## ✨ 核心特性 (Features)

### 🎨 3D 像素软光栅引擎 (PixelEngine)
- **等轴测深度渲染**：支持 30° 正交透视投影、浮点深度缓冲（Z-Buffer）与像素级几何遮挡。
- **复古色彩算法**：内置 **Bayer 4×4** 矩阵有序抖动算法，配合冷暖色相偏移渐变（Shadows Drift to Violet, Lights Drift to Warm Yellow）。
- **动态物理表现**：实时投射阴影、多层地面贴花融合、程序化风力扰动与树叶草丛摇曳。

### 🎳 经典 Balote（法式滚球）场景
- **拟真球体物理**：具备完整的 3D 重力抛物线弹道、地面减速摩擦与球体间弹性碰撞模拟。
- **智能 AI 行为树**：敌方角色根据实时战局与目标球位置自主评估蓄力强度与投掷轨迹。
- **战局测量与结算**：自动测算各球离黄色目标小球（Jack）的距离，回合胜负实时计分。

### 🖥️ 原生 macOS 动态桌面壁纸
- **零干扰安全层级**：壁纸窗口工作于系统 `kCGDesktopWindowLevel`，处于桌面壁纸与桌面图标之间，绝不遮挡、截断任何正常软件窗口。
- **桌面点击交互**：支持在 Finder 前台点击桌面空白处直接操控箱庭小球，无需切换窗口。
- **低功耗感知**：全屏软件覆盖或显示器休眠时自动挂起渲染循环，极致省电。

### 🎛️ 菜单栏常驻 (Menu Bar Extra)
- 快速切换动态桌面壁纸开关。
- 一键暂停/恢复画面渲染。
- 一键静音与快速唤起偏好设置。

### 🔊 纯程序化音效合成 (Procedural Audio)
- 基于 macOS 原生 `AVAudioEngine` 与 `AVAudioPCMBuffer`，在内存中动态生成方波、正弦波与三角波。
- 零外部音频文件依赖，复古 8-bit / 16-bit 击球清脆撞击、木板回响与挥臂破空声即时合成。

### ⚙️ 丰富平滑的偏好设置
- **渲染帧率**：支持 30 FPS（极致节能）、60 FPS（流畅平衡）与 120 FPS（ProMotion 高刷）。
- **背景风格**：支持深浅纯色底色自适应或完全透明背景（箱庭悬浮于当前桌面壁纸之上）。
- **画面缩放**：50% ~ 120% 无级平滑自由缩放，随时重置推荐比例。

---

## 🎮 玩法与交互 (Controls)

| 操作方式 | 动作说明 |
| :--- | :--- |
| **鼠标拖拽** | 在发球区向后拖拽红球蓄力，松开即可投掷；拖拽距离越远，投出力度越大 |
| **键盘快捷键** | 按下 `Space`（空格）或 `Enter`（回车）快速发球 |
| **胜负规则** | 每轮投掷后，比对手最佳球更靠近黄色小目标球（Jack）的红球均得 1 分，率先获得 5 分者获胜 |

---

## 📂 项目结构 (Project Structure)

```text
Hakoniwa/
├── Hakoniwa/
│   ├── Core/
│   │   ├── PixelEngine.swift         # 3D 像素软光栅透视渲染引擎
│   │   ├── MathUtils.swift           # 插值、缓动与噪声数学工具
│   │   ├── Scene.swift               # 箱庭场景抽象协议
│   │   ├── AppSettings.swift         # 用户持久化配置与管理
│   │   └── HakoniwaAppModel.swift    # 状态分发与渲染循环总控
│   ├── Scenes/
│   │   └── BaloteScene.swift         # 法式滚球场景逻辑、物理模拟与 AI
│   ├── Wallpaper/
│   │   ├── WallpaperManager.swift    # 原生桌面底层壁纸窗口管理
│   │   └── DesktopEventMonitor.swift # 桌面空白处事件监听
│   ├── Render/
│   │   └── PixelCanvasNSView.swift   # 高性能 Direct-to-Bitmap 渲染画布
│   ├── Audio/
│   │   └── SoundManager.swift        # 程序化合成器音效管理器
│   ├── ContentView.swift             # 独立主窗口及交互 HUD
│   ├── SettingsView.swift            # 偏好设置面板 (TabView)
│   └── HakoniwaApp.swift             # 应用入口与 MenuBarExtra
├── Scripts/
│   ├── package_dmg.sh                # 全自动 DMG 打包与视觉对齐脚本
│   ├── generate_dmg_background.swift # PixelEngine 同款 3D 像素 DMG 背景生成器
│   └── generate_icon.swift           # 原生全尺寸 ICNS 图标生成脚本
├── LICENSE                           # MIT 开源许可证（包含第三方致谢声明）
└── README.md
```

---

## 🛠️ 构建与运行 (Build & Run)

### 环境要求
- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0+
- Swift 5.9+

### 1. 本地编译运行
克隆仓库后直接通过 Xcode 打开项目：
```bash
git clone https://github.com/Cicada000/Hakoniwa.git
cd Hakoniwa
open Hakoniwa.xcodeproj
```
选择 `Hakoniwa` Scheme，点击 **Run** (⌘R) 即可启动。

### 2. 构建 DMG 发布镜像
项目内置全套自动化打包脚本，会自动利用 `PixelEngine` 在编译期实时光栅化渲染出同款等轴测 3D 像素全景安装背景，并自动配置 Finder 布局：
```bash
chmod +x Scripts/package_dmg.sh
./Scripts/package_dmg.sh
```
构建完成后可在 `dist/Hakoniwa-v1.0.dmg` 找到精美的安装镜像。

---

## 📄 开源协议与致谢 (License & Acknowledgements)

本项目遵循 [MIT License](LICENSE) 开源协议。

### 致谢 (Acknowledgements)

Hakoniwa 的 3D 像素正交投影渲染架构 (`PixelEngine.swift`)、Balote 法式滚球场景算法与物理规则 (`BaloteScene.swift`)，以及程序化音频合成参数 (`SoundManager.swift`) 参考并移植自优秀的前端开源项目 **[pixel-plays](https://github.com/amirmushichge/pixel-plays)**。

- **Upstream 项目**：[pixel-plays](https://github.com/amirmushichge/pixel-plays)
- **原作者**：[Amir Mushich](https://github.com/amirmushichge)
- **原协议**：MIT License

特此对原作者 **Amir Mushich** 富有创意的像素渲染算法与优雅的设计表达诚挚敬意与感谢！原项目完整的 MIT 版权声明已妥善保留于本仓库的 [LICENSE](LICENSE) 文件中。
