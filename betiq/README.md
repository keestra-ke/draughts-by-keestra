# BetIQ — Kotlin native app (Android Studio)

A complete Kotlin project. The app is a **WebView shell** around the bundled web
build in `app/src/main/assets/`, served from a secure `appassets.androidplatform.net`
origin via `WebViewAssetLoader` so localStorage, cookies and the service worker work.

## Open & build

1. Install **Android Studio** (Koala or newer) and Android SDK 34.
2. **File → Open** → select this folder.
3. Let Gradle sync (it downloads Gradle 8.9 and the AndroidX dependencies).
4. **Run ▶** on a device/emulator, or:
   - `./gradlew assembleDebug` → `app/build/outputs/apk/debug/app-debug.apk`
   - `./gradlew assembleRelease` (sign with your own keystore)

> The Gradle wrapper JAR is not included. Android Studio generates it on first sync,
> or run `gradle wrapper --gradle-version 8.9` once.

## What's inside

```
settings.gradle.kts / build.gradle.kts / gradle.properties
gradle/wrapper/gradle-wrapper.properties
app/build.gradle.kts
app/src/main/AndroidManifest.xml
app/src/main/java/com/betiq/pro/MainActivity.kt
app/src/main/assets/        index.html, sw.js, vendor/, icons/, manifest
app/src/main/res/           theme, colours, strings, launcher icons
```

## Notes

- `applicationId` is `com.betiq.pro`, versionCode 587, minSdk 22, targetSdk 34.
- To point the app at a hosted Worker instead of the bundled build, change the
  `loadUrl(...)` call in `MainActivity.kt` to your HTTPS URL; keep the bundled
  assets as an offline fallback if you need one.
- Cloud sync is configured inside the app: **Settings → 6 · Cloud sync**.
- Signing: create a keystore in Android Studio (**Build → Generate Signed Bundle/APK**)
  or pass signing config in `app/build.gradle.kts`.
