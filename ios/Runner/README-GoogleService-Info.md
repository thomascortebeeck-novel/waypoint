# GoogleService-Info.plist (Firebase iOS)

**Do not commit this file.** It contains API keys and is in `.gitignore`. Each developer/CI must obtain it from Firebase Console.

Firebase Core reports: **Could not locate configuration file: 'GoogleService-Info.plist'** until this file is added.

## What to do

1. Open [Firebase Console](https://console.firebase.google.com) and select your project.
2. Add an **iOS app** (or use the existing one) with **bundle ID**: `com.thomascortebeeck.waypoint`.
3. Download **GoogleService-Info.plist** and place it in this directory:  
   `ios/Runner/GoogleService-Info.plist`
4. In Xcode, ensure the file is included in the **Runner** target (drag it into the Runner group and check "Copy items if needed" / target membership **Runner**).

After that, Firebase will stop logging "No app has been configured" and features that depend on the plist (e.g. Crashlytics, some Auth config) will work.

## Security

- **Never commit** `GoogleService-Info.plist` to the repo (it contains your Firebase/Google API key).
- If this key was ever committed, **rotate it** in [Google Cloud Console](https://console.cloud.google.com/apis/credentials): open the key, revoke or create a new one, and re-download the plist from Firebase Console.
