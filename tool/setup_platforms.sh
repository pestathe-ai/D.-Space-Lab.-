#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --project-name d_space_lab --org dev.dspacelab --platforms=android .
rm -f test/widget_test.dart
M=android/app/src/main/AndroidManifest.xml
PERMS='    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />\
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />\
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />'
sed -i "s#<application#${PERMS}\n    <application#" "$M"
sed -i 's#android:label="[^"]*"#android:label="D. Space Lab"#' "$M"
PROV='        <provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.files" android:exported="false" android:grantUriPermissions="true">\
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths" />\
        </provider>\
    </application>'
sed -i "s#</application>#${PROV}#" "$M"
grep -n "permission\|label\|provider" "$M"
MA=$(find android/app/src/main -name MainActivity.kt | head -1)
cp tool/android/MainActivity.kt "$MA"
echo "MainActivity: $MA"
cp -r tool/android/res/. android/app/src/main/res/
cp -r tool/icon/res/. android/app/src/main/res/
cp tool/android/proguard-rules.pro android/app/proguard-rules.pro
# androidx.core per FileProvider
G=$(ls android/app/build.gradle.kts android/app/build.gradle 2>/dev/null | head -1)
if [[ "$G" == *.kts ]]; then
  printf '\ndependencies {\n    implementation("androidx.core:core-ktx:1.13.1")\n}\n' >> "$G"
else
  printf '\ndependencies {\n    implementation "androidx.core:core-ktx:1.13.1"\n}\n' >> "$G"
fi
flutter pub get
