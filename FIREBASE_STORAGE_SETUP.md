# Firebase Storage Setup Guide

This guide will help you set up Firebase Storage for your Waypoint app to enable image uploads for plan cover images and day-by-day images.

## Prerequisites
- Firebase project already connected to your app
- Firebase Console access
- Project must have Firebase Storage enabled

---

## Step 1: Enable Firebase Storage in Google Cloud Console

### 1.1 Navigate to Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on **"Storage"** in the left sidebar
4. Click **"Get Started"**

### 1.2 Enable Storage
1. Review the security rules dialog
2. Click **"Next"**
3. Select a Cloud Storage location (choose one closest to your users):
   - `europe-west1` (Belgium) - Recommended for European users
   - `us-central1` (Iowa) - Recommended for US users
   - `asia-northeast1` (Tokyo) - Recommended for Asian users
4. Click **"Done"**

> **Note**: The storage location cannot be changed after setup!

---

## Step 2: Configure Firebase Storage Security Rules

Storage security rules control who can read/write to your Firebase Storage buckets.

### 2.1 Navigate to Rules
1. In Firebase Console, go to **Storage** → **Rules** tab
2. You'll see the default rules

### 2.2 Update Security Rules

Replace the default rules with the following:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Public read access for all plan images
    match /plans/{planId}/{allPaths=**} {
      // Anyone can read (for displaying in marketplace/details)
      allow read: if true;
      
      // Only authenticated users can write
      allow write: if request.auth != null;
    }
    
    // Private user uploads (if needed in future)
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### 2.3 Publish Rules
1. Click **"Publish"** to apply the new rules
2. Wait for confirmation message

---

## Step 3: Storage Structure

Your images will be organized as follows:

```
firebase-storage-bucket/
└── plans/
    └── {planId}/
        ├── cover.jpg              # Plan cover image
        └── days/
            ├── day_1.jpg          # Day 1 image
            ├── day_2.jpg          # Day 2 image
            └── day_N.jpg          # Day N image
```

### Storage Paths Explained:
- **Cover Images**: `plans/{planId}/cover.{extension}`
- **Day Images**: `plans/{planId}/days/day_{dayNumber}.{extension}`

---

## Step 4: Cost Considerations

Firebase Storage pricing (as of 2024):
- **Storage**: $0.026/GB/month
- **Download**: $0.12/GB
- **Upload**: Free
- **Free Tier**: 5GB storage, 1GB/day downloads

### Typical Usage Estimates:
- **Cover Image**: ~500KB (optimized)
- **Day Image**: ~300KB (optimized)
- **5-day plan with images**: ~2MB total
- **100 plans**: ~200MB storage (~$0.005/month)

> **Tip**: Compress images before upload to reduce costs and improve performance!

---

## Step 5: Verify Setup

### 5.1 Test Upload
1. In your app, navigate to the Builder screen
2. Try uploading a cover image in Step 1
3. Check Firebase Console → Storage to see if the image appears

### 5.2 Test Download
1. Publish a plan with images
2. Navigate to the plan details page
3. Verify images load correctly in the day carousel

---

## Step 6: Security Best Practices

### ✅ DO:
- Validate file types and sizes in your app before upload
- Compress images client-side before uploading
- Use authenticated uploads only (already implemented)
- Set appropriate CORS rules if accessing from web

### ❌ DON'T:
- Allow unlimited file sizes (implement max 5MB limit)
- Store sensitive user data in public paths
- Use predictable file names (use UUIDs, already implemented)

---

## Troubleshooting

### Issue: "Firebase Storage is not configured"
**Solution**: Make sure Firebase Storage is enabled in the Firebase Console (Step 1)

### Issue: "Permission denied" errors
**Solution**: 
1. Check security rules are published (Step 2)
2. Verify user is authenticated before uploading
3. Check the storage path matches the rules

### Issue: Images not loading in app
**Solution**:
1. Verify download URL is valid in Firestore
2. Check CORS settings in Firebase Console
3. Ensure images are publicly readable (check security rules)

### Issue: Upload fails silently
**Solution**:
1. Check app logs in Dreamflow Debug Console
2. Verify internet connection
3. Check Firebase Storage quota limits

---

## Additional Configuration

### Enable CORS for Web (if needed)
If accessing storage from web, create a `cors.json` file:

```json
[
  {
    "origin": ["*"],
    "method": ["GET"],
    "maxAgeSeconds": 3600
  }
]
```

Apply using Google Cloud SDK:
```bash
gsutil cors set cors.json gs://your-project-id.appspot.com
```

---

## Next Steps

- ✅ Cover image upload implemented
- ✅ Per-day image upload implemented
- ✅ Plan details screen displays images in carousel
- ✅ Storage service handles all uploads

You're all set! Users can now:
1. Upload cover images when creating plans
2. Upload images for each day of their itinerary
3. View beautiful image carousels on the plan details page

---

## Support

For issues or questions:
- Check [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- Review app logs in Dreamflow Debug Console
- Contact Firebase Support for account-specific issues
