import com.android.build.gradle.BaseExtension
import org.gradle.api.tasks.compile.JavaCompile

allprojects {
    repositories {
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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
// 关键：必须改 AGP 扩展上的 compileOptions，而不是直接改 JavaCompile 任务属性。
// 插件自己的 build.gradle 写着 android { compileOptions { ... VERSION_1_8 } }，
// AGP 是在任务被实例化时才把扩展里的值写进 JavaCompile 的；直接设任务属性会先被
// 我们写上、随后被 AGP 用扩展里的 1.8 覆盖回去（旧补丁就是这样失效的）。
// 在 afterEvaluate 里改扩展值，AGP 稍后读到的就是 17。
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByType(BaseExtension::class.java)?.compileOptions?.apply {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
