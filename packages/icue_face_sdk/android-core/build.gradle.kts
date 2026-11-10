plugins {
    id("com.android.library") version "9.0.1"
    id("maven-publish")
}

group = "school.icue"
version = "0.2.0"

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
    namespace = "school.icue.face.core"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            assets.directories.add("../android/src/main/assets")
            jniLibs.directories.add(liteRtNativeDirectory.get().asFile.absolutePath)
        }
    }

    androidResources {
        noCompress += "tflite"
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
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
    implementation("androidx.activity:activity-ktx:1.12.3")
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")
    implementation("androidx.camera:camera-view:1.6.1")
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
    implementation("com.google.ai.edge.litert:litert-api:2.1.6")

    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}

tasks.named("preBuild").configure {
    dependsOn(extractLiteRtNativeRuntime)
}

publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = project.group.toString()
            artifactId = "icue-face-core"
            version = project.version.toString()

            afterEvaluate {
                from(components["release"])
            }
        }
    }
}
