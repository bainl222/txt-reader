plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.txt_reader"
    compileSdk = 36
    
    // 之前为了解决 file_picker 报错指定了特定的 NDK 版本，保留这个即可
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.txt_reader"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 暂时使用 debug 签名，方便直接打包测试
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ==========================================
    // 核心新增部分：打包时自动带上版本号重命名
    // ==========================================
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            // 你的 App 名字，可以随意修改，比如 "我的阅读器"
            val appName = "TxtReader" 
            val vName = variant.versionName
            val vCode = variant.versionCode
            // 最终文件名格式如：TxtReader-v1.0.0(1)-release.apk
            output.outputFileName = "${appName}-v${vName}(${vCode})-${variant.buildType.name}.apk"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}