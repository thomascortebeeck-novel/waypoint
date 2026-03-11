# GoogleService-Info.plist (Firebase iOS)

Firebase Core reports: **Could not locate configuration file: 'GoogleService-Info.plist'** until this file is added.

## What to do

1. Open [Firebase Console](https://console.firebase.google.com) and select your project.
2. Add an **iOS app** (or use the existing one) with **bundle ID**: `com.thomascortebeeck.waypoint`.
3. Download **GoogleService-Info.plist** and place it in this directory:  
   `ios/Runner/GoogleService-Info.plist`
4. In Xcode, ensure the file is included in the **Runner** target (drag it into the Runner group and check “Copy items if needed” / target membership **Runner**).

After that, Firebase will stop logging “No app has been configured” and features that depend on the plist (e.g. Crashlytics, some Auth config) will work.
