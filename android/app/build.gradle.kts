android {
    namespace "com.seu.app"
    compileSdk 36   // ← AQUI: 36, não 34!

    defaultConfig {
        applicationId "com.seu.app"
        minSdk 21
        targetSdk 36
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }

    // ← ADICIONA ESSA PARTE AQUI:
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

// ← ADICIONA TAMBÉM NO FINAL:
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
