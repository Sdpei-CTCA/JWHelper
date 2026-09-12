# JWHelper Android 端 ProGuard/R8 规则文件。
#
# ── 本文件如何生效（与实际构建一致）────────────────────────────────────
# R8 不在 android/app/build.gradle.kts 中显式配置：release 构建类型的
# minify / 资源收缩 / 规则文件接入，全部由 Flutter Gradle 插件在配置阶段注入：
#   packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt（位于 Flutter SDK 内）
#     if (FlutterPluginUtils.shouldShrinkResources(project)) {
#         getByName("release") {
#             isMinifyEnabled = true
#             isShrinkResources = FlutterPluginUtils.isBuiltAsApp(project)
#             proguardFiles(
#                 getDefaultProguardFile("proguard-android-optimize.txt"),
#                 flutterProguardRules,   # Flutter SDK 自带规则
#                 "proguard-rules.pro"    # ← 本文件（第三个规则文件）
#             )
#         }
#     }
# 插件源码中的原文注释："Fallback to `android/app/proguard-rules.pro`.
# This way, custom Proguard rules can be configured as needed."
# 也就是说：在本文件中新增的 keep 规则会参与 release 构建，无需再改 build.gradle.kts。
#
# 例外情况（两条，均与"本文件是否生效"有关）：
#   1. Flutter CLI 仅在特殊拆分构建时传 -Pshrink=false
#      （shouldShrinkResources 默认返回 true），此时插件不为 release 注入上述配置；
#   2. 若未来移除 dev.flutter.flutter-gradle-plugin，或在无插件环境下直接以 Gradle
#      构建，需在 build.gradle.kts 的 release 块显式配置
#      isMinifyEnabled / isShrinkResources / proguardFiles，
#      否则本文件不会被读取。
#
# ── release 构建中的实际规则来源 ──────────────────────────────────────
#   1. proguard-android-optimize.txt —— AGP 官方默认优化规则（不含 -dontoptimize）
#   2. flutter_proguard_rules.pro    —— Flutter SDK 自带规则（保留 io.flutter.* 反射入口等）
#   3. 各依赖库 AAR/JAR 内嵌 consumer 规则（flutter_local_notifications、Glance 等）
#   4. 本文件
#
# 当前事实（可在 build/app/outputs/mapping/release/ 下核实）：
#   - 该目录的 mapping.txt / configuration.txt 与 release APK 由同一次构建产出；
#   - configuration.txt 中无任何全局禁用（-dontoptimize / -dontshrink / -dontobfuscate），
#     R8 全量优化（AGP 8 默认 Full Mode）实际生效；
#   - 因此本文件当前无需任何 keep 规则，请保持"最小化"原则。
#
# 仅当新增依赖或出现 release-only 崩溃时，在此按以下优先级添加最小化规则：
#   精确成员 > 具体类 > 包级通配 > 全局 -dont*（全局禁用属最后手段，尽量避免）。
#
# 示例（按需取消注释）：
# -keepclassmembers class com.example.lib.ReflectiveEntry { <init>(); }
