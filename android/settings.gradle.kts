pluginManagement {
    val flutterSdkPath =
        run {
            val props = java.util.Properties()
            file("local.properties").inputStream().use { props.load(it) }
            props.getProperty("flutter.sdk")
                ?: error("flutter.sdk not set in local.properties")
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.13.1" apply false   // أو نسخة مناسب لك
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
