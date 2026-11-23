plugins {
    id("com.android.application")
}

android {
    namespace = "org.alpinekde.mobile"
    compileSdk = 35

    defaultConfig {
        applicationId = "org.alpinekde.mobile"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.2.0"
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("org.apache.commons:commons-compress:1.27.1")
}
