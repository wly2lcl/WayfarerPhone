plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// QA is opt-in and must never produce a production/profile artifact.
val wayfarerQa = providers.gradleProperty("wayfarerQa").map {
    it.toBooleanStrictOrNull()
        ?: throw GradleException("wayfarerQa must be true or false (debug builds only).")
}.getOrElse(false)

// Do not load key.properties or fall back to the debug keystore.
val signingEnvironment = listOf(
    "WF_ANDROID_STORE_FILE",
    "WF_ANDROID_STORE_PASSWORD",
    "WF_ANDROID_KEY_ALIAS",
    "WF_ANDROID_KEY_PASSWORD",
).associateWith { providers.environmentVariable(it).orNull }
val missingSigningVariables = signingEnvironment.filterValues { it.isNullOrBlank() }.keys

val validateWayfarerBuildMode = tasks.register("validateWayfarerBuildMode") {
    doLast {
        if (wayfarerQa) {
            throw GradleException(
                "wayfarerQa=true is debug-only. Remove -PwayfarerQa=true for release/profile builds.",
            )
        }
    }
}
val validateWayfarerSigning = tasks.register("validateWayfarerSigning") {
    dependsOn(validateWayfarerBuildMode)
    doLast {
        if (missingSigningVariables.isNotEmpty()) {
            throw GradleException(
                "Android release signing is required. Set non-blank environment variables: " +
                    missingSigningVariables.joinToString(", ") +
                    ". Debug signing fallback is disabled.",
            )
        }
    }
}

// Validate actual variant tasks even for abbreviated, aggregate, or up-to-date builds.
tasks.configureEach {
    if (name.contains("Release", ignoreCase = true)) {
        dependsOn(validateWayfarerSigning)
    } else if (
        name.contains("Profile", ignoreCase = true) &&
        !name.contains("Debug", ignoreCase = true)
    ) {
        // Debug ART-profile tasks are still debug tasks, not Flutter profile builds.
        dependsOn(validateWayfarerBuildMode)
    }
}

android {
    namespace = "dev.wayfarer.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.wayfarer.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (missingSigningVariables.isEmpty()) {
            create("release") {
                storeFile = file(signingEnvironment.getValue("WF_ANDROID_STORE_FILE")!!)
                storePassword = signingEnvironment.getValue("WF_ANDROID_STORE_PASSWORD")
                keyAlias = signingEnvironment.getValue("WF_ANDROID_KEY_ALIAS")
                keyPassword = signingEnvironment.getValue("WF_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            if (wayfarerQa) {
                applicationIdSuffix = ".qa"
            }
        }
        release {
            signingConfig = signingConfigs.findByName("release")
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
