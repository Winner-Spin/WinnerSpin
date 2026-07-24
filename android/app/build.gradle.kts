import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val signingEnvironment = mapOf(
    "storeFile" to System.getenv("ANDROID_KEYSTORE_PATH"),
    "storePassword" to System.getenv("ANDROID_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("ANDROID_KEY_PASSWORD"),
)
val environmentSigningRequested = signingEnvironment.values.any { !it.isNullOrBlank() }
if (!environmentSigningRequested && keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

val releaseSigning = if (environmentSigningRequested) {
    signingEnvironment
} else {
    signingEnvironment.keys.associateWith { keystoreProperties.getProperty(it) }
}
val missingSigningValues = releaseSigning.filterValues { it.isNullOrBlank() }.keys
val releaseKeystore = releaseSigning["storeFile"]
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }
val releaseSigningError = when {
    environmentSigningRequested && missingSigningValues.isNotEmpty() ->
        "Incomplete Android release signing environment: ${missingSigningValues.joinToString()}"
    !environmentSigningRequested && !keystorePropertiesFile.exists() ->
        "Android release signing is not configured. Copy key.properties.example " +
            "to android/key.properties and provide the local upload-keystore credentials."
    missingSigningValues.isNotEmpty() ->
        "Missing Android release signing properties: ${missingSigningValues.joinToString()}"
    releaseKeystore?.isFile != true ->
        "The configured Android release keystore file does not exist."
    else -> null
}
val releaseSigningConfigured = releaseSigningError == null

val validateReleaseSigning by tasks.registering {
    group = "verification"
    description = "Validates the Android release signing configuration."
    doLast {
        releaseSigningError?.let { throw GradleException(it) }
    }
}

android {
    namespace = "com.winnerspin.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.winnerspin.game"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = releaseSigning.getValue("storePassword")
                keyAlias = releaseSigning.getValue("keyAlias")
                keyPassword = releaseSigning.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild") {
        dependsOn(validateReleaseSigning)
    }
}

flutter {
    source = "../.."
}
