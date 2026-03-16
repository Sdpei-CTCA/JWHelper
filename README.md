<div align="center">
  <img src="assets/images/logo.png" alt="Logo" width="120" height="120">
  


# 教务小助手
</div>
基于 Flutter 开发的山东体育学院教务系统数据查看APP，提供课表、考试、成绩、学业进度查询，以及教学评价辅助、离线缓存和多端运行能力。

## 项目概览

- 项目名称：JWHelper
- 当前版本：1.2.2
- 技术栈：Flutter + Provider + Dio + SharedPreferences
- 支持平台：Android、iOS、Windows、macOS、Linux
- 主要定位：个人教务信息查询与轻量辅助操作

## 功能特性

- 登录认证：支持教务系统账号登录、记住密码、自动登录、验证码处理。
- 课表查询：按日期查看课程，支持刷新和本地缓存。
- 考试安排：支持学期、考试批次、校区筛选。
- 成绩查询：支持按学期筛选成绩并读取缓存。
- 学业进度：展示培养方案完成度、学分信息和课程明细。
- 教学评价辅助：检测未完成评价并提供手动评教入口。
- 离线模式：网络异常时优先读取本地缓存数据。
- 小组件支持：支持 Android 和 iOS 小组件同步课表、学业进度摘要。
- 更新检查：内置版本检测与下载入口。

## 界面结构

登录后首页包含四个主标签页：

- 课表
- 考试
- 成绩
- 进度

应用层统一处理以下流程：

- 登录后的数据预加载
- 教学评价状态检测
- 小组件点击跳转
- 关于页与更新检查展示

## 技术实现

### 状态管理

项目使用 Provider。全局数据集中在 DataProvider 中，并通过按领域拆分的 mixin 管理不同模块的数据加载逻辑。

### 网络层

项目使用 Dio 统一请求，通过 CookieJar 维护会话。部分数据来自教务系统 HTML 或接口解析，因此当上游页面结构发生变化时，需要同步调整解析逻辑。

### 缓存策略

- 成绩、课表、进度、考试信息使用 SharedPreferences 做本地缓存。
- 网络失败时优先回退到缓存。
- 切换账号时会清空当前内存态与对应缓存。

### 项目分层

当前 lib 目录采用分层结构：

```text
lib/
├── app/               # 应用层：首页、协调器、全局状态、用例、更新服务
├── core/              # 基础层：配置与异常定义
├── features/          # 功能模块：auth / schedule / exam / grades / progress / evaluation
├── infrastructure/    # 基础设施：网络客户端、平台小组件服务
├── shared/            # 共享能力：主题管理
└── main.dart          # 应用入口
```

## 环境要求

- Flutter SDK：3.x
- Dart SDK：>= 3.0.0 < 4.0.0
- Android 开发：Android Studio 或可用 Android SDK
- iOS 开发：macOS + Xcode
- Windows 桌面开发：Visual Studio C++ 桌面组件

建议先执行：

```bash
flutter doctor
```

## 快速开始

### 1. 获取代码

```bash
git clone https://github.com/Sdpei-CTCA/JWHelper.git
cd JWHelper/flutter_app
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行项目

```bash
flutter run
```

常用运行方式：

```bash
# 指定 Android 设备
flutter run -d <device-id>

# 指定 Windows
flutter run -d windows

# 指定 Web
flutter run -d chrome
```

## 构建说明

### Android

```bash
# 调试构建
flutter build apk --debug

# Release APK
flutter build apk --release

# 按 ABI 拆分
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-info

# App Bundle
flutter build appbundle --release
```

产物目录：

- build/app/outputs/flutter-apk/
- build/app/outputs/bundle/

### iOS

```bash
# Release 构建
flutter build ios --release

# 不签名构建
flutter build ios --release --no-codesign


如需手动打包 ipa，可在生成 Runner.app 后自行封装 Payload 目录。
# 封装方式
# 1. 创建一个名为 Payload 的文件夹
mkdir Payload

# 2. 将生成的 Runner.app 复制到 Payload 文件夹中
cp -r build/ios/iphoneos/Runner.app Payload/

# 3. 将 Payload 文件夹压缩为 zip
zip -r -y Payload.zip Payload/

# 4. 将 zip 重命名为 ipa
mv Payload.zip app-unsigned.ipa
```


### Windows

```bash
flutter build windows --release
```

## 常用开发命令

```bash
# 静态检查
flutter analyze lib

# 运行测试
flutter test

# 清理构建缓存
flutter clean
```

## 依赖说明

核心依赖包括：

- provider：状态管理
- dio：网络请求
- dio_cookie_manager / cookie_jar：会话与 Cookie 管理
- shared_preferences：本地缓存
- html：HTML 解析
- home_widget：小组件同步
- url_launcher：外部链接打开
- google_fonts：字体
- flutter_animate：界面动画

## 使用说明

### 登录

- 输入学号和密码。
- 如系统要求验证码，界面会自动展示验证码输入与刷新区域。
- 登录成功后会进入首页，并触发数据预加载。

### 离线模式

当网络失败且本地存在历史缓存时，应用会尝试进入离线模式，允许继续查看部分数据。

### 教学评价提醒

如果教务系统检测到未完成教学评价，应用会弹出提醒。你可以：

- 直接跳转网页评价
- 打开应用内手动评教页面

## 注意事项

- 本项目依赖教务系统当前页面结构和接口行为。如果上游 HTML 或接口字段变更，相关解析逻辑需要同步更新。
- Web 端可能受浏览器跨域限制影响，部分登录或数据请求能力不如原生端稳定。
- 小组件能力依赖平台插件实现，优先在 Android/iOS 真机验证。
- MaterialIcons tree-shaken 构建提示通常属于正常优化，不是错误。

## 故障排查

### 运行后界面异常

优先尝试：

```bash
flutter clean
flutter pub get
flutter run
```

### Android 调试包表现异常

如果热重载后界面异常但完整重编译恢复，通常属于调试增量产物或缓存问题，可重新安装 debug 包验证。

### analyze 有提示

先执行：

```bash
flutter analyze lib
```

当前项目常见的是样式优化级别提示，不一定是功能性错误。

## 许可证与来源说明

本项目核心思路与部分业务逻辑参考以下项目：

- 原项目：https://github.com/Chendayday-2005/JiaoWuXiTong
- 原作者：Chendayday-2005

当前项目遵循 GPL-3.0 许可证，详见 LICENSE。
