# Font Setup Instructions

## Critical: Font Files Must Be Downloaded

The code has been updated to use local font files instead of Google Fonts CDN, but **you must download the font files** and place them in the `assets/fonts/` directory.

## Required Font Files

Download the following font files from [Google Fonts](https://fonts.google.com/specimen/DM+Sans) and [DM Serif Display](https://fonts.google.com/specimen/DM+Serif+Display):

### DM Sans
- `DMSans-Regular.ttf` (weight: 400)
- `DMSans-Medium.ttf` (weight: 500)
- `DMSans-SemiBold.ttf` (weight: 600)
- `DMSans-Bold.ttf` (weight: 700)

### DM Serif Display
- `DMSerifDisplay-Regular.ttf`
- `DMSerifDisplay-Italic.ttf`

## Steps

1. Create the directory: `assets/fonts/` (already created)
2. Download all 6 font files from Google Fonts
3. Place them in `assets/fonts/`
4. Run `flutter pub get` to register the fonts
5. Restart your app

## Verification

After adding the fonts, you should see:
- No console errors about fonts not loading
- DM Serif Display used for adventure titles (36px)
- DM Sans used for all UI text

## Current Status

✅ `pubspec.yaml` - Fonts registered
✅ `typography.dart` - Using `fontFamily: 'DMSans'` and `'DMSerifDisplay'`
✅ `waypoint_theme.dart` - Using `fontFamily: 'DMSans'`
✅ `main.dart` - `GoogleFonts.config.allowRuntimeFetching = false` already set

⏳ **YOU NEED TO**: Download and place the 6 font files in `assets/fonts/`

