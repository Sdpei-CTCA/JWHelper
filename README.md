<div align="center">
  <img src="assets/images/logo.png" alt="Logo" width="120" height="120" style="border-radius: 25%;">
  


# 教务小助手
</div>
基于 Flutter 开发的山东体育学院教务系统数据查看APP，提供课表、考试、成绩、学业进度查询，以及智慧考勤签到、教学评价辅助、离线缓存和多端运行能力。

## 项目概览

- 项目名称：JWHelper
- 当前版本：1.4.5
- 技术栈：Flutter + Provider + Dio + SharedPreferences
- 支持平台：Android、iOS、Windows、macOS、Linux
- 主要定位：个人教务信息查询与轻量辅助操作

## 功能特性

- 登录认证：支持教务系统账号登录、记住密码、自动登录、验证码处理；会话过期（`logintimeout`）时尝试静默重登，失败再引导回登录页。
- 课表查询：支持列表视图和网格视图两种课表展示模式，按日期查看课程，支持刷新和本地缓存；区分「本学期未发布课表」与「保留本地课表」两种空课表状态。
- 课表外观自定义：支持设置课表壁纸背景、自动提取主题配色、调整壁纸不透明度和位置，以及独立控制列表/网格模式的课程卡片透明度。内置春/夏/秋/冬四季主题与经典白/黑六套默认配色方案。
- 全局主题配色：壁纸提取的主色、辅色、点缀色会自动应用到导航栏、AppBar、按钮、开关、下拉框、标签等全局 UI 元素，并针对浅色/深色模式分别适配亮度和对比度。底部导航栏支持半透明效果。
- 考试安排：支持学期、考试批次、校区筛选；考试周默认进入考试页，小组件同步展示考试信息。
- 成绩查询：支持按学期筛选成绩并读取缓存；空数据时支持下拉刷新与「刷新」按钮，有数据时移除顶部重复加载条。
- 学业进度：展示培养方案完成度、学分信息和课程明细。
- 智慧考勤签到：底部「考勤」标签页内直接是智慧考勤页面（应用内网页版），可完成上课签到、下课签退、到场签到（含人脸活体）与考勤统计查询。使用「智慧山体」统一认证账号，与教务账号相互独立；首次使用需填写学号与密码，之后可在「设置与关于 → 智慧考勤账号」中修改或清除。
- 教学评价辅助：检测未完成评价并提供手动评教入口；文字题至少输入 10 个字符方可提交。
- 离线模式：网络异常时优先读取本地缓存数据。
- 小组件支持：Android / iOS 桌面小组件同步「今日课表」与「学业进度」；设置页可检查闹钟、通知（提醒）及 HyperOS 自启动权限，iOS 学业进度小组件支持点击跳转 App。
- 动态导航 URL：登录后拉取教务 `BuildMenu` 解析成绩/进度/考试/评教等业务地址，失败时回退 `Config` 常量。
- 更新检查：内置版本检测（GitHub + Gitee），检测到新版本时在课表页底部显示浮动更新提示卡片，点击即可跳转更新详情。
- 主题切换：支持浅色、深色和跟随系统三种外观模式。
- 多包共存：Android Debug 包使用 `.dev` 后缀与独立应用名，可与 Release 包同时安装。

## 界面结构

应用直接进入课表页面（利用缓存），底部导航栏支持半透明效果，包含五个主标签页：

- 课表（支持列表/网格视图切换，网格模式下周选择器集成在标题栏）
- 考勤（智慧考勤页面，应用内网页版；未配置账号时先展示绑定表单）
- 考试
- 成绩
- 进度

应用层统一处理以下流程：

- 缓存优先加载 + 后台自动登录
- 会话过期检测与静默重登（`SessionExpiredCoordinator`）
- 教学评价状态检测
- 小组件点击跳转（`jwhelper://schedule|exam|progress|attendance`）
- 课前提醒通知点击跳转（点通知直接进入考勤页，冷启动同样生效）
- 版本更新浮动提示
- 设置与关于页面（含课表外观自定义、主题切换、校区选择、课前提醒开关、**智慧考勤账号**、桌面小组件权限、更新检查、退出登录等）

## 技术实现

### 状态管理

项目使用 Provider。全局数据集中在 DataProvider 中，并通过按领域拆分的 mixin 管理不同模块的数据加载逻辑。主题由 ThemeProvider 和 WallpaperProvider 协同管理。

### 网络层

项目使用 Dio 统一请求，通过 CookieJar 维护会话。登录后会并行拉取 `BuildMenu` 菜单树，由 `JwEndpointResolver` 解析各业务模块页面与 Handler 地址；拉取失败时回退 `Config` 中的固定 URL。部分数据仍来自教务系统 HTML 或接口解析，因此当上游页面结构发生变化时，需要同步调整解析逻辑。

当接口返回 `logintimeout` 时，`ApiClient` 会触发全局会话过期处理，优先尝试保留密码的静默重登。

### 缓存策略

- 成绩、课表、进度、考试信息使用 SharedPreferences 做本地缓存。
- 壁纸路径、提取的配色、卡片透明度等外观设置同样持久化到 SharedPreferences。
- 网络失败时优先回退到缓存。
- 切换账号时会清空当前内存态与对应缓存。

### 项目分层

当前 lib 目录采用分层结构：

```text
lib/
├── app/               # 应用层：首页、协调器、全局状态、用例、更新服务
├── core/              # 基础层：配置与异常定义
├── features/          # 功能模块：auth / attendance / schedule / exam / grades / progress / evaluation / navigation
├── infrastructure/    # 基础设施：网络客户端、通知、平台小组件与权限检测
├── shared/            # 共享能力：主题管理（ThemeProvider / WallpaperProvider）
└── main.dart          # 应用入口
```

## 环境要求

- Flutter SDK：3.32.0+
- Dart SDK：>= 3.9.0 < 4.0.0
- Android 开发：Android Studio 或可用 Android SDK，另需 **JDK 17**（AGP 9 的最低要求）
- Android 构建链：**Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0**（与 Flutter 3.47 模板一致；低于这套版本时 `flutter build` 会给出「soon be dropped」预警，下个 Flutter 稳定版将直接构建失败）
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
cd JWHelper
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
```

如需手动打包 ipa，可在生成 Runner.app 后自行封装 Payload 目录。

### Windows

```bash
flutter build windows --release
```

## CI / 自动发布

仓库包含 GitHub Actions 工作流 `.github/workflows/build-on-push.yml`：

- **触发**：
  - **Pull Request → `main`**：只运行 `flutter test`，不构建、不发布，用于快速校验
  - **push → `main`**：完整流程（测试 → 构建 → 发布）
  - **手动运行（`workflow_dispatch`）**：可在 Actions 页针对任意分支触发并执行完整构建；
    由于发布条件绑定默认分支，在非 `main` 分支上手动运行不会产生 Release
  - 三种触发都带路径过滤：若某次改动**只**涉及 `**.md`、`LICENSE`、`.gitignore`、
    `.gitattributes`、`codemagic.yaml`、`env.sample` 或 `.github/**`，整条流水线会被跳过。
    因此**改动 workflow 自身不会自动触发构建**，需要用上面的手动运行来验证
- **流程**：`flutter test`（未通过则不进入构建）→ 构建 Android Release APK 与 iOS 未签名 ipa
  （构建仅在 push 到 `main` 或手动运行时执行）
- **构建命令**：
  - Android：`flutter build apk --release --obfuscate --split-debug-info=./debug-info --split-per-abi`
  - iOS：`flutter build ios --release --no-codesign`，随后封装为 Payload ipa
- **产物**：
  - `app-arm64-v8a-release.apk`、`app-armeabi-v7a-release.apk`、`app-x86_64-release.apk`
  - 每个 APK 附同名 `.sha1` 校验文件
  - `JWHelper-<版本>-nosign.ipa`（未签名，需自行签名后安装）
  - 混淆符号表 `debug-info-<run_number>`（保留 90 天，用于还原混淆后的堆栈）
- **发布**：仅当推送到默认分支时创建 Pre-release，标签为 `daily-YYYY-MM-DD`（北京时间）；
  同名标签会更新并替换旧资产。该 Pre-release 为 `prerelease: true` 且 `makeLatest: false`，
  因此不会成为 GitHub 的 Latest，**也不会被 App 内的更新检查识别为可用更新**。
- **并发**：同一分支上连续推送时，新运行会取消先前的未完成运行，只保留最后一次；但默认分支
  上的运行不会被取消，以免中断已经进行到一半的发布。

> Android 产物沿用 Flutter 的默认命名。App 内的更新检查是按文件名里的 ABI 关键字
> （`arm64-v8a` / `armeabi-v7a` / `x86_64`）挑选对应架构的 APK 的，因此重命名时
> 必须保留 ABI 片段，否则会下载到错误架构的安装包。

可选在仓库 Secrets 中配置 Android 签名（`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEY_ALIAS`、
`ANDROID_KEY_PASSWORD`、`ANDROID_STORE_PASSWORD`）；未配置时使用调试签名。

## 常用开发命令

```bash
# 静态检查
flutter analyze lib

# 运行测试
flutter test

# 清理构建缓存
flutter clean
```

## 使用说明

### 启动优化

应用采用「缓存优先」启动策略：

1. 打开 App 后直接进入课表页面，利用本地缓存立即展示数据，无需等待网络。
2. 自动登录在后台异步进行，底部显示浮动状态提示（正在自动登录…）。
3. 登录成功后静默刷新在线数据；失败时显示重试提示卡片。

### 登录

- 首次使用需输入学号和密码登录。
- 如系统要求验证码，界面会自动展示验证码输入与刷新区域。
- 支持记住密码和自动登录，后续打开 App 自动进入课表。

### 离线模式

当网络失败且本地存在历史缓存时，应用会尝试进入离线模式，允许继续查看部分数据。

### 课表外观自定义

在「设置与关于 → 课表外观自定义」中可以：

- 从相册选择壁纸作为课表背景
- 调整壁纸图片的显示位置（上下左右移动）
- 自动从壁纸中提取主色、辅色、点缀色，应用到全局 UI
- 调整壁纸不透明度（数值越大壁纸越淡）
- 独立调整列表模式和网格模式的课程卡片透明度
- 实时预览两种模式下的卡片效果
- 选择六套默认主题（春·新绿、夏·盛夏、秋·金秋、冬·雪境、经典白、经典黑），无需壁纸即可改变全局配色

### 教学评价提醒

如果教务系统检测到未完成教学评价，应用会弹出提醒。你可以：

- 直接跳转网页评价
- 打开应用内手动评教页面（文字题需至少 10 字）

### 智慧考勤签到

底部导航栏的「考勤」标签页即智慧考勤（应用内网页版），功能（上课签到、下课签退、到场签到的人脸活体、考勤统计与异常明细）都由学校官方页面提供。

- **首次使用**：进入标签页会先要求填写「智慧山体」统一认证的学号与密码（与教务系统账号相互独立）。保存时会立即校验一次登录，**校验通过才会进入考勤页面**；不通过会停在表单并给出原因。凭据一旦保存，之后重新打开 App 会直接进入考勤页，不需要再填一次。
- **图形验证码**：密码连续输错后，统一认证会要求输入图形验证码（4 位）。此时表单会自动多出验证码输入框与图片，点图片可换一张；校验通过后自动用已保存的账号密码完成登录。验证码是一次性的，无法保存下来复用。
- **账号修改**：在「设置与关于 → 智慧考勤账号」中可修改学号密码，弹窗内也提供「清除账号」。**密码与登录令牌都保存在系统加密存储中**（Android 走 Keystore 支撑的 EncryptedSharedPreferences，iOS 走 Keychain），只有学号这类非敏感信息留在 SharedPreferences；退出教务登录不会清除考勤账号。
- **免登录进入**：进入标签页时会用已保存账号换取统一认证令牌，并把它写入 Cookie 与 Web Storage，尽量直接进入考勤页面而无需再登录一次。
- **标题栏按钮**：重新加载、重新登录（令牌失效时使用）、智慧考勤账号（直接改绑）、用浏览器打开（相机或长页面在 WebView 里不顺手时的退路）都放在首页标题栏那一行，仅在进入过考勤页后显示。
- **切换标签不重载**：考勤页在首次打开后会常驻（切走时只是隐藏），切到课表/成绩等再回来不会重新加载网页。
- **定位权限**：签到与签退需要上报当前位置，首次在网页里发起定位时系统会询问定位权限，允许后即可正常签到；若之前拒绝过，页面会提示并在提示条上提供「去设置」。
- **从上课提醒进入**：课前提醒通知的正文会提示「点击可进入考勤签到」，点击通知直接切到考勤页（应用没在运行时点击通知冷启动也生效）。
- **令牌自愈**：缓存的统一认证令牌失效时，进入页面会用已保存的密码自动重新登录一次；仍失败则只在网页版上方提示，网页内自身仍可登录。
- **桌面端**：Windows / Linux 没有可用的应用内 WebView（`webview_flutter` 只覆盖 Android/iOS/macOS），考勤页会直接给出「用浏览器打开」入口，而不是报错；签到与统计功能在浏览器里一致。
- **统计**：出勤率、异常次数与异常明细都在官方页面的「考勤统计」里查看。

### 桌面小组件

在「设置与关于 → 桌面小组件」中可查看：

- 添加「今日课表」「学业进度 / 绩点与学分」小组件的方式
- **闹钟**（精确闹钟，`SCHEDULE_EXACT_ALARM`）与 **通知（提醒）**（`POST_NOTIFICATIONS`）权限状态
- 小米 / 红米机型的 **自启动** 引导（HyperOS 无法自动检测，需手动确认）

小组件数据在打开 App 并加载课表 / 进度后自动同步；课表小组件在 Android 上依赖精确闹钟在每节课结束、跨天时刷新。

## 注意事项

- 本项目依赖教务系统当前页面结构和接口行为。如果上游 HTML 或接口字段变更，相关解析逻辑需要同步更新。
- 智慧考勤页面来自独立服务 `qdxt.sdpei.edu.cn`，其地址与统一认证客户端信息（`clientId`、`appname` 等）都固定在 `lib/features/attendance/` 下，学校侧变更时需要同步修改。
- 应用内网页版需要放行网页的定位与摄像头请求，这两项都依赖平台实现：
  - **定位**：签到/签退要上报位置，网页里的 `navigator.geolocation` 只有在宿主 App 获得定位授权后才会返回坐标。Android 的 WebView 默认拒绝该请求，应用会在网页发起定位时申请系统权限再放行（`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` 已声明）；iOS 交给系统弹窗（已声明 `NSLocationWhenInUseUsageDescription`）。若被永久拒绝，页面会提示并在提示条上提供「去设置」。
  - **相机**：到场签到的人脸活体需要相机。Android 同样由应用申请系统权限后放行（`CAMERA` 已声明）；iOS 交给系统弹窗（已声明 `NSCameraUsageDescription`）。若个别机型仍无法调起相机，请用网页版顶部的「用浏览器打开」。
- Web 端可能受浏览器跨域限制影响，部分登录或数据请求能力不如原生端稳定。
- Android 构建链已升级到 **Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0**（JDK 17）。`android/gradle.properties` 中保留了两条 Flutter 迁移器写入的兼容开关（`android.newDsl=false`、`android.builtInKotlin=false`），即 AGP 9 的「内置 Kotlin」尚未启用；`device_info_plus`、`flutter_timezone`、`home_widget`、`package_info_plus`、`shared_preferences_android`、`webview_flutter_android` 目前仍自行应用 Kotlin Gradle Plugin，**未来版本的 Flutter 会拒绝构建这类插件**，需等它们升级后再切到内置 Kotlin。
- `gradle.properties` 里的 `kotlin.incremental=false` 是刻意保留：依赖插件的 Kotlin 源码在 pub 缓存（与应用不在同一磁盘/根目录），而构建目录被 Flutter 重定位，Kotlin 增量编译缓存无法计算相对路径，Kotlin 2.4 起会直接导致编译失败。
- 小组件能力依赖平台插件实现，优先在 Android/iOS 真机验证；Android 12+ 需单独授予「闹钟和提醒」权限。
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
