#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --project-name d_space_lab --org dev.dspacelab --platforms=android .
rm -f test/widget_test.dart
M=android/app/src/main/AndroidManifest.xml
sed -i 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android"#<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"#' "$M"
PERMS='    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />\
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" tools:ignore="QueryAllPackagesPermission" />\
    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />\
    <uses-permission android:name="android.permission.REQUEST_DELETE_PACKAGES" />\
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />\
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />'
sed -i "s#<application#${PERMS}\n    <application#" "$M"
sed -i 's#android:label="[^"]*"#android:label="D. Space Lab"#' "$M"
# applicazione nostra (registro errori, WorkManager su richiesta)
sed -i 's#android:name="${applicationName}"#android:name=".SpaceLabApp"#' "$M"
PROV='        <provider android:name="androidx.startup.InitializationProvider" android:authorities="${applicationId}.androidx-startup" android:exported="false" tools:node="merge">\
            <meta-data android:name="androidx.work.WorkManagerInitializer" android:value="androidx.startup" tools:node="remove" />\
        </provider>\
        <provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.files" android:exported="false" android:grantUriPermissions="true">\
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths" />\
        </provider>\
    </application>'
sed -i "s#</application>#${PROV}#" "$M"
grep -n "permission\|label\|provider" "$M"
MA=$(find android/app/src/main -name MainActivity.kt | head -1)
cp tool/android/MainActivity.kt "$MA"
cp tool/android/CleanupWorker.kt "$(dirname "$MA")/CleanupWorker.kt"
cp tool/android/SpaceLabApp.kt "$(dirname "$MA")/SpaceLabApp.kt"
grep -q 'SpaceLabApp' "$M" || { echo "error: applicazione non impostata nel manifest"; exit 1; }
echo "MainActivity: $MA"
cp -r tool/android/res/. android/app/src/main/res/
cp -r tool/icon/res/. android/app/src/main/res/
cp tool/android/proguard-rules.pro android/app/proguard-rules.pro
# androidx: FileProvider, EXIF delle foto, pulizia programmata
G=$(ls android/app/build.gradle.kts android/app/build.gradle 2>/dev/null | head -1 || true)
if [[ "$G" == *.kts ]]; then
  printf '\ndependencies {\n    implementation("androidx.core:core-ktx:1.13.1")\n    implementation("androidx.exifinterface:exifinterface:1.3.7")\n    implementation("androidx.work:work-runtime-ktx:2.9.1")\n}\n' >> "$G"
else
  printf '\ndependencies {\n    implementation "androidx.core:core-ktx:1.13.1"\n    implementation "androidx.exifinterface:exifinterface:1.3.7"\n    implementation "androidx.work:work-runtime-ktx:2.9.1"\n}\n' >> "$G"
fi
# Android 11+ (accesso a tutti i file)
sed -i -E 's/minSdk(Version)? *=? *flutter\.minSdkVersion/minSdk = 30/' "$G"
grep -n "minSdk" "$G" || true
flutter pub get
