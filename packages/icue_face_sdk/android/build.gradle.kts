group = "school.icue.icue_face_sdk"
version = "0.2.0"

buildscript {
    val kotlinVersion = "2.2.20"

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

val liteRtNativeRuntime = configurations.create("liteRtNativeRuntime") {
    isCanBeConsumed = false
    isCanBeResolved = true
    isTransitive = false
}
val liteRtNativeDirectory = layout.buildDirectory.dir("generated/litertNative")
val extractLiteRtNativeRuntime = tasks.register<Sync>("extractLiteRtNativeRuntime") {
    from(liteRtNativeRuntime.elements.map { files -> files.map { zipTree(it.asFile) } }) {
        include("jni/**")
        eachFile { path = path.removePrefix("jni/") }
        includeEmptyDirs = false
    }
    into(liteRtNativeDirectory)
}

android {
    namespace = "school.icue.icue_face_sdk"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("../android-core/consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.directories.addAll(listOf("src/main/kotlin", "../android-core/src/main/kotlin"))
            jniLibs.directories.add(liteRtNativeDirectory.get().asFile.absolutePath)
        }
        getByName("test") {
            java.directories.addAll(listOf("src/test/kotlin", "../android-core/src/test/kotlin"))
        }
    }

    androidResources {
        noCompress += "tflite"
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    add(liteRtNativeRuntime.name, "com.google.ai.edge.litert:litert:2.1.6@aar")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
    implementation("androidx.activity:activity-ktx:1.12.3")
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")
    implementation("androidx.camera:camera-view:1.6.1")
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
    implementation("com.google.ai.edge.litert:litert-api:2.1.6")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.21.0")
}

tasks.named("preBuild").configure {
    dependsOn(extractLiteRtNativeRuntime)
}
