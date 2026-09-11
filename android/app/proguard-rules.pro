# JWHelper Android 端 ProGuard/R8 规则文件。
#
# 本文件由 Flutter Gradle 插件自动挂接到 release 构建
# （见 flutter_tools/gradle/FlutterPlugin.kt 的 proguardFiles 调用）。
# release 构建实际参与 R8 的规则由三部分组成：
#   1. proguard-android-optimize.txt —— AGP 官方默认优化规则（不含 -dontoptimize）
#   2. flutter_proguard_rules.pro    —— Flutter SDK 自带规则（保留 io.flutter.* 反射入口等）
#   3. 各依赖库 AAR/JAR 内嵌的 consumer 规则（flutter_local_notifications、Glance 等）
#
# 当前事实（经 release 构建产物核实）：
#   - R8 全量优化已默认启用：minify + 资源收缩 + Full Mode；
#   - configuration.txt 中无任何全局禁用（-dontoptimize / -dontshrink / -dontobfuscate）；
#   - 本文件当前无需任何额外 keep 规则，请保持"最小化"原则。
#
# 仅当新增依赖或出现 release-only 崩溃时，在此按以下优先级添加最小化规则：
#   精确成员 > 具体类 > 包级通配 ＞ 全局 -dont*（全局禁用属最后手段，尽量避免）。
#
# 示例（按需取消注释）：
# -keepclassmembers class com.example.lib.ReflectiveEntry { <init>(); }
