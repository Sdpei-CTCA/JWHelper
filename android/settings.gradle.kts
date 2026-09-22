pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // 与 build.gradle.kts 同一套策略：CI（CI=true）走官方源，本地走国内镜像；
    // Flutter 引擎仓库加 content 过滤，避免 androidx 等构件撞上镜像的 502。
    val isCi: Boolean = System.getenv("CI") == "true"
    repositories {
        maven {
            url = uri(
                if (isCi) "https://storage.googleapis.com/download.flutter.io"
                else "https://storage.flutter-io.cn/download.flutter.io"
            )
            content { includeGroupByRegex("io\\.flutter.*") }
        }
        if (!isCi) {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 与 Flutter SDK 模板保持一致的组合（Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0），
    // 低于这套版本时 flutter build 会给出「soon be dropped」预警。
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
