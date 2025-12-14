<div align="center">
  <img src="assets/images/logo.png" alt="Logo" width="120" height="120">
  
  # 教务小助手 (JiaoWuXiTong Mobile)
</div>

这是一个基于 Flutter 开发的教务系统移动端客户端，旨在为学生提供便捷的教务信息查询服务。本项目适配了 `jw.sdpei.edu.cn` 教务系统，支持多平台运行（Android, iOS, Windows, macOS, Linux, Web）。

## ✨ 功能特性

*   **用户登录**: 支持教务系统账号登录，自动管理会话（Cookie）。
*   **课表查询**: 查看个人学期课表，支持周次切换。
*   **成绩查询**: 快速查询各学期成绩详情。
*   **学业进度**: 查看培养方案完成情况及学业进度。

## 🚀 快速开始

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

# 构建 App Bundle (用于 Google Play)
flutter build appbundle --release
```
构建产物位于: `build/app/outputs/flutter-apk/`

### iOS (IPA)

*需要 macOS 环境和 Xcode*

```bash
flutter build ios --release
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

[MIT License](LICENSE)
