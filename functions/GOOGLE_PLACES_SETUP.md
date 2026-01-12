# 🔒 Secure Google Places API Setup Guide

## Overview

This guide explains how to securely configure Google Places API integration using Firebase Cloud Functions as a backend proxy. This approach protects your API key and implements rate limiting.

---

## ✅ Benefits of This Architecture

### Security
- ✅ API key never exposed to client apps
- ✅ Impossible to extract from compiled app
- ✅ Server-side validation and authentication
- ✅ Protected from decompilation attacks

### Cost Control
- ✅ Rate limiting (100 requests/hour/user/endpoint)
- ✅ Usage monitoring through Firebase Console
- ✅ Abuse prevention with authentication checks

### Flexibility
- ✅ Can switch API providers without app updates
- ✅ Can add caching layers server-side
- ✅ Can implement custom business logic
- ✅ Photo caching reduces API costs significantly

---

## 📋 Setup Instructions

### Step 1: Get Google Places API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new API key or use existing one
3. Enable these APIs:
   - **Places API (New)** - for place search and details
   - **Geocoding API** - for address-to-coordinates conversion
4. Copy your API key

### Step 2: Configure API Key Restrictions

**IMPORTANT:** Restrict your API key to Cloud Functions only:

1. In Google Cloud Console → API Credentials
2. Click on your API key
3. Under **Application restrictions**:
   - Select "HTTP referrers (websites)"
   - Add: `https://*.cloudfunctions.net/*`
   - Add: `https://*.run.app/*` (for Gen 2 functions)
4. Under **API restrictions**:
   - Select "Restrict key"
   - Enable only:
     - Places API (New)
     - Geocoding API

This ensures the key ONLY works from your Cloud Functions, not from client apps.

### Step 3: Set Environment Variable

Set the API key as an environment variable in Firebase:

```bash
# Using Firebase CLI (recommended for production)
firebase functions:config:set google.places_key="YOUR_API_KEY_HERE"

# OR for local development, create .env file in functions directory
echo "GOOGLE_PLACES_API_KEY=YOUR_API_KEY_HERE" > functions/.env
```

### Step 4: Deploy Cloud Functions

```bash
# Install dependencies
cd functions
npm install

# Build TypeScript
npm run build

# Deploy to Firebase
firebase deploy --only functions
```

This will deploy 4 secure endpoints:
- `placesSearch` - Autocomplete search
- `placeDetails` - Get place information
- `geocodeAddress` - Address to coordinates
- `placePhoto` - Fetch and cache photos

### Step 5: Test Your Functions

You can test the functions using Firebase Console:
1. Go to Firebase Console → Functions
2. Click on each function
3. Use the "Test" tab to send sample requests

Example test payload for `placesSearch`:
```json
{
  "query": "restaurant",
  "proximity": {
    "lat": 37.7749,
    "lng": -122.4194
  },
  "types": ["restaurant"]
}
```

---

## 🔐 Security Features

### Authentication Required
All functions require Firebase Authentication. Users must be signed in to use Google Places features.

### Rate Limiting
Each user is limited to:
- **100 requests per hour** per endpoint
- Tracked in Firestore collection: `rate_limits`
- Automatic reset after 1 hour

### Error Handling
Graceful error messages for:
- `unauthenticated` - User must sign in
- `resource-exhausted` - Rate limit exceeded
- `invalid-argument` - Missing/invalid parameters
- `internal` - Server errors

---

## 📊 Cost Optimization

### Photo Caching Strategy
Photos are fetched once from Google and cached permanently in Firebase Storage:

1. **First Request**: 
   - Fetches from Google Places API (costs 1 API call)
   - Uploads to Firebase Storage
   - Returns public URL

2. **Subsequent Requests**:
   - Returns cached URL instantly (no API call)
   - Shared across ALL users
   - Permanent caching (never expires)

**Cost Savings Example:**
- Popular place with 1000 views
- **Without caching**: 1000 API calls = $7 USD
- **With caching**: 1 API call = $0.007 USD
- **Savings**: 99.9% reduction in photo costs

### Search Result Limits
- Autocomplete results limited to 5 per query
- Reduces API costs while maintaining UX

---

## 🚨 Migration from Insecure Implementation

If you previously had `lib/config/api_keys.dart`:

### ✅ What Changed
1. ❌ **Removed**: `lib/config/api_keys.dart` (exposed API key)
2. ❌ **Removed**: Direct HTTP calls to Google APIs
3. ✅ **Added**: Secure Cloud Functions proxy
4. ✅ **Added**: Authentication checks
5. ✅ **Added**: Rate limiting
6. ✅ **Added**: Photo caching

### 🔄 Migration Steps
1. Deploy new Cloud Functions (see Step 4)
2. App automatically uses new secure endpoints
3. **CRITICAL**: Rotate your old API key in Google Cloud Console
4. Update API restrictions as described in Step 2

---

## 🔍 Monitoring & Debugging

### View Logs
```bash
# View function logs
firebase functions:log

# View specific function
firebase functions:log --only placesSearch
```

### Monitor Rate Limits
Check Firestore collection `rate_limits` to see usage patterns:
```
rate_limits/{userId}_{endpoint}
  - count: number of requests
  - timestamp: window start time
```

### Monitor Storage Usage
Firebase Console → Storage → `waypoint-photos/`
- See all cached photos
- Monitor storage costs

---

## 🛡️ Additional Security Recommendations

### 1. Enable Firebase App Check
Prevent unauthorized access to Cloud Functions:
```bash
firebase apps:platforms:add appcheck --app-id YOUR_APP_ID
```

### 2. Set Up Billing Alerts
Google Cloud Console → Billing → Budgets & Alerts:
- Set alert at $50, $100, $200 usage
- Get notified of unexpected spikes

### 3. Review Security Rules
Ensure Firestore security rules protect `rate_limits` collection:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rate_limits/{document=**} {
      allow read, write: if false; // Only Cloud Functions can access
    }
  }
}
```

---

## 📞 Support

For issues or questions:
1. Check Firebase Functions logs
2. Verify API key restrictions in Google Cloud Console
3. Test functions in Firebase Console
4. Review error messages in app logs

---

## 🎯 Architecture Diagram

```
┌─────────────────┐
│   Flutter App   │
│  (Client-side)  │
└────────┬────────┘
         │ (Authenticated requests)
         │
         ▼
┌─────────────────────────┐
│  Firebase Cloud         │
│  Functions              │
│  ┌─────────────────┐    │
│  │ placesSearch    │    │
│  │ placeDetails    │    │
│  │ geocodeAddress  │    │
│  │ placePhoto      │    │
│  └────────┬────────┘    │
│           │             │
│  ┌────────▼─────────┐   │
│  │ Rate Limiting    │   │
│  │ (Firestore)      │   │
│  └──────────────────┘   │
└────────┬────────────────┘
         │ (API key secured server-side)
         │
         ▼
┌─────────────────────────┐
│  Google Places API      │
│  - Autocomplete         │
│  - Place Details        │
│  - Geocoding            │
│  - Photos               │
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Firebase Storage       │
│  (Photo Cache)          │
└─────────────────────────┘
```

---

**Last Updated**: December 2024  
**Status**: ✅ Production Ready
