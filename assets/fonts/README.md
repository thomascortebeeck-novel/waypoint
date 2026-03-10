# Font assets (mobile/desktop fallback)

Web loads **DM Sans** and **DM Serif Display** via CSS from `web/index.html`.  
For mobile and desktop, Flutter uses local assets declared in `pubspec.yaml`.

Add these `.ttf` files here (download from [Google Fonts](https://fonts.google.com/specimen/DM+Sans) and [DM Serif Display](https://fonts.google.com/specimen/DM+Serif+Display)):

- `DMSerifDisplay-Regular.ttf`
- `DMSerifDisplay-Italic.ttf`
- `DMSans-Regular.ttf`
- `DMSans-Medium.ttf`
- `DMSans-SemiBold.ttf`
- `DMSans-Bold.ttf`

Then run `flutter pub get` and `flutter build web` (or run on a device) to verify.
