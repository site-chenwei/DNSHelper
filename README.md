# DNS助手 (DNSHelper)

DNS助手 是一款基于 HarmonyOS Next 开发的原生应用，旨在为用户提供便捷的 DNS 服务管理体验。用户可以自定义配置多个 DNS 服务器，并根据需求快速切换和激活指定的 DNS 服务。

## 核心功能

- **多 DNS 管理**：支持添加、编辑和删除自定义 DNS 服务器配置（如 Google DNS, Cloudflare, 阿里云 DNS 等）。
- **一键切换**：在配置列表中选择目标 DNS，一键激活并应用到系统网络设置。
- **状态可视**：实时显示当前生效的 DNS 服务信息。

## 技术栈

- **操作系统**: HarmonyOS Next (API 9+)
- **开发语言**: ArkTS
- **UI 框架**: ArkUI
- **构建工具**: Hvigor

## 快速开始

1. **环境准备**:
   - 安装最新版 DevEco Studio。
   - 配置 HarmonyOS Next SDK。

2. **获取代码**:
   ```bash
   git clone git@github.com:site-chenwei/DNSHelper.git
   ```

3. **运行项目**:
   - 使用 DevEco Studio 打开项目根目录。
   - 等待 Hvigor Sync 完成依赖同步。
   - 连接真机或启动模拟器，点击 `Run 'entry'`。

## 开发规范

本项目遵循严格的代码规范与开发流程，详情请查阅 [AI_RULES.md](./AI_RULES.md)。

- **单一事实来源 (SSOT)**: 所有规范以 `AI_RULES.md` 为准。
- **提交规范**: 严格被动提交 (Explicit Commit Only)，仅在明确指令下执行 Git 操作。
- **语言要求**: 全项目（包括注释、文档、提交信息）强制使用中文。
