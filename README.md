<div align="center">
  <img src="assets/images/logo.png" alt="Logo" width="120" height="120">
  


# 教务小助手 (JiaoWuXiTong Helper)
</div>

基于 Flutter 开发的教务系统移动客户端，旨在为山体学生提供便捷的教务信息查询服务。

## ✨ 功能特性

*   **用户登录**: 支持教务系统账号登录，自动管理会话。
*   **课表查询**: 查看个人学期课表，支持周次切换。
*   **成绩查询**: 快速查询各学期成绩详情。
*   **学业进度**: 查看培养方案完成情况及学业进度。
*   **离线模式**: 支持离线查看缓存的课表和成绩数据。
*   **小组件支持(beta)**: 支持Android和iOS小组件，快速查看课表和成绩概览。

## ✨ 使用指南

### 📥 下载与安装

*   请前往本项目的 [Releases](https://github.com/Sdpei-CTCA/JWHelper/releases) 页面下载最新版本的安装包。
    *   **Android 用户**: 下载 `.apk` 文件并安装。
    *   **iOS 用户**: 下载 `.ipa` 文件并通过sideloadly或爱思助手自签并安装（详情可参考相关教程）。

### 🔑 登录与使用

1.  **登录**:
    *   **学号**: 输入您的山东体育学院教务系统学号。
    *   **密码**: 输入对应的教务系统密码。
    *   **验证码**: 根据提示输入验证码（如有）。
    *   *注：应用支持记住密码功能，下次打开可自动登录。*
2.  **离线模式**:
    *   如果网络不稳定或无法连接教务系统，应用将尝试进入离线模式，显示本地缓存的数据。

## �🚀 快速开始

### 环境要求

*   Flutter SDK: `>=3.0.0 <4.0.0`
*   Dart SDK: 对应 Flutter 版本

### 安装步骤

1.  **克隆项目**
    ```bash
    git clone https://github.com/Sdpei-CTCA/JWHelper
    cd flutter_app
    ```

2.  **安装依赖**
    ```bash
    flutter pub get
    ```

### 运行项目

连接设备或启动模拟器后，运行以下命令：

```bash
# 运行在默认设备
flutter run

# 运行在特定设备 (例如 Windows)
flutter run -d windows

# 运行 Release 模式 (性能更好)
flutter run --release
```

## 📦 打包构建

### Android (APK)

```bash
# 构建 Release APK
flutter build apk --release
# 构建适用不同架构，系统版本的APK
flutter build apk --release --obfuscate --split-debug-info=./debug-info --split-per-abi
# 构建 App Bundle (用于 Google Play)
flutter build appbundle --release
```
构建产物位于: `build/app/outputs/flutter-apk/`

### iOS (IPA)

*需要 macOS 环境和 Xcode*

```bash
#普通搭建
flutter build ios --release
```
```bash
#无签名
flutter build ios --release --no-codesign
#生成app后：

# 1. 创建一个名为 Payload 的文件夹
mkdir Payload

# 2. 将生成的 Runner.app 复制到 Payload 文件夹中
cp -r build/ios/iphoneos/Runner.app Payload/

# 3. 将 Payload 文件夹压缩为 zip
zip -r -y Payload.zip Payload/

# 4. 将 zip 重命名为 ipa
mv Payload.zip app-unsigned.ipa
```

### Windows (.exe)

```bash
flutter build windows --release
```

## 📂 项目结构

```
lib/
├── api/            # 网络请求服务 (Auth, Grades, Schedule 等)
├── models/         # 数据模型 (Grade, ScheduleItem 等)
├── providers/      # 状态管理 (AuthProvider, DataProvider)
├── screens/        # UI 页面 (Login, Home, Grades 等)
├── config.dart     # 全局配置 (API URL 等)
└── main.dart       # 程序入口
```

## ⚠️ 注意事项

*   本项目通过解析 HTML 页面获取数据，如果教务系统页面结构发生变化，可能导致解析失败，需要更新 `api/` 目录下的解析逻辑。
*   请勿将包含个人隐私信息的构建产物上传到公共仓库。

## 📄 许可证
本Flutter项目的核心逻辑来源于以下Python项目：
    - 项目名称：[山东体育学院教务小助手](https://github.com/Chendayday-2005/JiaoWuXiTong)
    - 原作者：[@Chendayday-2005](https://github.com/Chendayday-2005)
[GPL3.0 License](LICENSE)
