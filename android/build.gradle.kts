import com.android.build.gradle.BaseExtension
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

// GitHub Actions 等绝大多数 CI 会自动设置环境变量 CI=true。
// CI 机器（境外）直连官方仓库又快又稳；本地（国内网络）走国内镜像。
// 本文件与 settings.gradle.kts 的 pluginManagement 采用同一套策略，需同步修改。
val isCi: Boolean = System.getenv("CI") == "true"

allprojects {
    repositories {
        // Flutter 引擎构件仓库。它只托管 io.flutter.* 的包，必须加 content 过滤：
        // 不过滤时 androidx 等所有构件都会先请求它，而 storage.flutter-io.cn 对
        // 不存在的路径返回 502 而非 404，Gradle 会判定该仓库故障并直接判死整个构建
        // ——这正是 GitHub Actions 上 mergeReleaseNativeLibs 解析失败的原因。
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
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 依赖插件统一按 Java 17 编译（消除 JDK 25 javac 的“源值/目标值 8 已过时”警告），
// :app 除外——它已由自己的 compileOptions 指定 Java 17。
//
// 关键一：必须改 AGP 扩展上的 compileOptions，而不是直接改 JavaCompile 任务属性。
// 插件自己的 build.gradle 写着 android { compileOptions { ... VERSION_1_8 } }，
// AGP 是在任务被实例化时才把扩展里的值写进 JavaCompile 的；直接设任务属性会先被
// 我们写上、随后被 AGP 用扩展里的 1.8 覆盖回去（旧补丁就是这样失效的）。
// 在 afterEvaluate 里改扩展值，AGP 稍后读到的就是 17。
//
// 关键二：Kotlin 的 jvmTarget 必须一起改。home_widget 的 build.gradle 里写着
// kotlinOptions { jvmTarget = "1.8" }，只改 Java 侧会让 KGP 以
// 「Inconsistent JVM-target compatibility detected for tasks
//   'compileReleaseJavaWithJavac' (17) and 'compileReleaseKotlin' (1.8)」直接失败——
// 这个错误在增量构建里不会出现（Kotlin 任务被跳过），只有干净构建才会暴露。
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByType(BaseExtension::class.java)?.compileOptions?.apply {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            tasks.withType(KotlinCompile::class.java).configureEach {
                compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
