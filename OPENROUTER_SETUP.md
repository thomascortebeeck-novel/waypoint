# OpenRouter API Key Setup

This guide explains how to set up the OpenRouter API key for the AI-powered travel context generation feature.

## What is OpenRouter?

OpenRouter is a unified API for accessing multiple AI models. We use it to call Claude Sonnet 4 for generating travel preparation information and local tips.

## Getting Your API Key

1. Go to [OpenRouter.ai](https://openrouter.ai/)
2. Sign up or log in to your account
3. Navigate to your [API Keys page](https://openrouter.ai/keys)
4. Click "Create Key" to generate a new API key
5. Copy the API key (it will look like: `sk-or-v1-...`)

## Setting the API Key in Firebase

The API key must be stored as a Firebase Functions secret to keep it secure (never commit it to git).

### Option 1: Using Firebase CLI (Recommended)

1. Make sure you have Firebase CLI installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Set the secret:
   ```bash
   firebase functions:secrets:set OPENROUTER_API_KEY
   ```
   
   When prompted, paste your OpenRouter API key and press Enter.

4. Verify the secret was set:
   ```bash
   firebase functions:secrets:access OPENROUTER_API_KEY
   ```

### Option 2: Using Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Functions** → **Secrets**
4. Click **Add Secret**
5. Enter the secret name: `OPENROUTER_API_KEY`
6. Paste your API key as the value
7. Click **Save**

## Deploying the Function

After setting the secret, deploy the Cloud Function:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions:generateAdventureContext
```

Or deploy all functions:

```bash
firebase deploy --only functions
```

## Verifying It Works

1. Open your Waypoint app
2. Go to the builder and create/edit an adventure
3. Fill in the required fields (name, location, description) in Step 1
4. Click the "✨ Generate Info" button
5. If successful, you should see travel preparation info and local tips populated in Steps 3 and 4

## Troubleshooting

### Error: "Missing required fields"
- Make sure you've filled in name, location, and description in Step 1

### Error: "API request failed"
- Check that the secret is set correctly: `firebase functions:secrets:access OPENROUTER_API_KEY`
- Verify your OpenRouter account has credits/balance
- Check Firebase Functions logs: `firebase functions:log`

### Error: "No content in API response"
- The AI model might be rate-limited or unavailable
- Check OpenRouter status page
- Try again after a few minutes

## Cost Considerations

OpenRouter charges based on token usage. Claude Sonnet 4 costs approximately:
- Input: ~$3 per 1M tokens
- Output: ~$15 per 1M tokens

Each generation request uses roughly:
- Input: ~500-1000 tokens
- Output: ~2000-4000 tokens

Estimated cost per generation: **$0.03 - $0.06**

Monitor your usage at [OpenRouter Dashboard](https://openrouter.ai/activity)

## Security Notes

- ✅ The API key is stored as a Firebase Functions secret (encrypted)
- ✅ The key never appears in client-side code
- ✅ All API calls go through the Cloud Function (server-side)
- ❌ Never commit the API key to git
- ❌ Never hardcode the key in your source files

