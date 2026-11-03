plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Single source of truth (ADR-025): the specs, templates, schema, prompts and fonts live in the
// iOS tree and are copied in at build time, never duplicated in android/.
val repoRoot = rootProject.projectDir.parentFile
val kitResources = File(repoRoot, "ios/WidgetKitCore/Sources/WidgetKitCore")
val sharedAssets = layout.buildDirectory.dir("generated/shared/assets")
val sharedRes = layout.buildDirectory.dir("generated/shared/res")

val copySharedAssets by tasks.registering(Sync::class) {
    into(sharedAssets)
    from(File(kitResources, "Resources/Templates")) { into("templates") }
    from(File(kitResources, "Resources/TestSpecs")) { into("testspecs") }
    from(File(kitResources, "Resources/Spec")) { into("spec") }
    from(File(kitResources, "Prompts")) { into("prompts") }
    from(File(repoRoot, "ios/Fonts")) {
        include("*.ttf", "*.otf")
        into("fonts")
    }
    // The icon whitelist (SF Symbol → Material Symbols name) is defined once, in Icons.swift.
    doLast {
        val swift = File(kitResources, "Spec/Icons.swift").readText()
        val pairs = Regex("\"([^\"]+)\": \"([^\"]+)\"").findAll(swift).joinToString(",\n") { m ->
            "  \"${m.groupValues[1]}\": \"${m.groupValues[2]}\""
        }
        File(sharedAssets.get().asFile, "spec/icons.json").apply { parentFile.mkdirs() }.writeText("{\n$pairs\n}\n")
        // The library order, defined once in TemplateLibrary.swift (catalogOrder).
        val library = File(kitResources, "Spec/TemplateLibrary.swift").readText()
        val block = library.substringAfter("static let catalogOrder = [").substringBefore("]")
        val ids = Regex("\"([^\"]+)\"").findAll(block).map { it.groupValues[1] }.toList()
        File(sharedAssets.get().asFile, "spec/catalog-order.txt").writeText(ids.joinToString("\n") + "\n")
    }
}

// Fonts as resources too, so live clocks (TextClock in RemoteViews) can name them in XML.
val copySharedFonts by tasks.registering(Sync::class) {
    into(sharedRes)
    from(File(repoRoot, "ios/Fonts")) {
        include("*.ttf")
        into("font")
        rename { name -> name.substringBeforeLast('.').replace(Regex("([a-z])([A-Z])"), "$1_$2").replace('-', '_').lowercase() + ".ttf" }
    }
}

android {
    namespace = "com.khaled.widgetstudio"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.khaled.widgetstudio"
        minSdk = 26
        targetSdk = 36
        versionCode = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionName = "0.1.0"
    }

    signingConfigs {
        // The release keystore comes from repository secrets in CI (ADR-025); never committed.
        val keystore = System.getenv("ANDROID_KEYSTORE_PATH")
        if (keystore != null) {
            create("release") {
                storeFile = file(keystore)
                storeType = "pkcs12"
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release")
        }
    }

    sourceSets["main"].assets.srcDir(sharedAssets)
    sourceSets["main"].res.srcDir(sharedRes)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

kotlin {
    jvmToolchain(17)
}

tasks.named("preBuild") { dependsOn(copySharedAssets, copySharedFonts) }

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.06.00")
    implementation(composeBom)
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.1")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.15.1")
    testImplementation("androidx.test:core:1.6.1")
}
