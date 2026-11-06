# Hakoniwa (箱庭)

> 原生 macOS 3D 像素艺术动态壁纸与交互小游戏桌面沙盘  
> Native macOS 3D Pixel Art Live Wallpaper & Interactive Desktop Toy

---

## 🌟 项目简介 (Overview)

**Hakoniwa (箱庭)** 是一款专为 macOS 设计的 3D 像素艺术沙盘应用。它既可以作为一个精致小巧的独立桌面应用运行，也能无缝融入 macOS 桌面，作为交互式动态壁纸常驻背景。

本项目采用纯原生 Swift 与 SwiftUI / AppKit 打造，内置自研轻量级 3D 像素正交投影渲染引擎，无需任何庞大臃肿的游戏引擎，在保证高保真像素美学与流畅物理交互的同时，保持极低的 CPU 和电量消耗。

---

## ✨ 核心特性 (Features)

- **3D 像素透视渲染引擎**：
  - 支持正交透视投影、深度缓冲（Z-Buffer）与遮挡处理。
  - Bayer 4×4 矩阵有序抖动算法与冷暖色彩渐变映射。
  - 实时投射阴影、多层地面着色、风力扰动与树叶草丛摇曳动效。
- **内置 Balote（法式滚球）场景**：
  - 拟真 3D 抛物线物理、地面摩擦与小球弹性碰撞。
  - AI 投掷策略决策、得分距离实时测算与胜负结算。
  - 支持鼠标交互投掷与键盘动作触发。
- **macOS 原生动态桌面壁纸**：
  - 壁纸层置于桌面图标与窗口底层之间，沉浸式点缀桌面且不干扰正常工作。
  - 全屏应用及桌面切换感知，节能暂停。
- **菜单栏快捷常驻 (Menu Bar Extra)**：
  - 一键开启/关闭桌面动态壁纸。
  - 快速暂停画面动画、静音音效或呼出设置面板。
- **纯程序化实时合成音效 (Procedural Audio)**：
  - 基于 `AVAudioEngine` 实时合成方波/正弦波/三角波音频，碰撞、撞板、破空声即时生成，零外部音频资源包依赖。
- **精美 DMG 打包脚本**：
  - 内置基于 PixelEngine 渲染的同款 3D 像素透视安装背景，支持一键打包 macOS 安装镜像。

---

## 🛠️ 构建与运行 (Build & Run)

### 开发环境要求
- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0+

### 直接运行
使用 Xcode 打开工程文件即可直接编译运行：
```bash
open Hakoniwa.xcodeproj
```

### 一键打包 DMG 安装镜像
项目自带全自动化打包脚本，会自动使用 PixelEngine 实时渲染 3D 像素安装背景并生成 `.dmg`：
```bash
chmod +x Scripts/package_dmg.sh
./Scripts/package_dmg.sh
```
打包产物将输出至 `dist/Hakoniwa-v1.0.dmg`。

---

## 📄 开源声明与致谢 (License & Attribution)

本项目采用 [MIT License](LICENSE) 开源协议。

### 致谢 (Acknowledgements)

Hakoniwa 的 3D 像素渲染引擎架构 (`PixelEngine.swift`)、Balote 球类场景物理模拟 (`BaloteScene.swift`) 以及程序化音效合成设计 (`SoundManager.swift`) 参考并移植自开源项目 **[pixel-plays](https://github.com/amirmushichge/pixel-plays)**。

- **原项目仓库**：[https://github.com/amirmushichge/pixel-plays](https://github.com/amirmushichge/pixel-plays)
- **原项目作者**：[Amir Mushich](https://github.com/amirmushichge)
- **开源协议**：MIT License

在此向原作者 **Amir Mushich** 的杰出创意与优秀的像素渲染算法致以诚挚的感谢！原项目的完整 MIT 许可声明已保留并在本仓库的 [LICENSE](LICENSE) 文件中详细列出。
