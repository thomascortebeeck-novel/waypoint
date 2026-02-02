# Fixing GitHub Actions Deployment Permission Issues

## Problem

If you see this error during deployment:
```
Error: Request to https://serviceusage.googleapis.com/v1/projects/***/services/artifactregistry.googleapis.com had HTTP Error: 403, Caller does not have required permission to use project ***. Grant the caller the roles/serviceusage.serviceUsageConsumer role
```

This means the service account used in GitHub Actions doesn't have permission to check/enable APIs.

## Solution

The service account needs the **Service Usage Consumer** role. Even though APIs are already enabled, Firebase CLI checks if it *can* enable them, which requires this permission.

### Option 1: Grant Role via Google Cloud Console (Recommended)

1. Go to [Google Cloud IAM & Admin](https://console.cloud.google.com/iam-admin/iam)
2. Select your project
3. Find your service account (the one used in `FIREBASE_SERVICE_ACCOUNT` secret)
4. Click the pencil icon to edit
5. Click "ADD ANOTHER ROLE"
6. Search for and select: **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`)
7. Click "SAVE"

### Option 2: Grant Role via gcloud CLI

```bash
# Replace with your actual project ID and service account email
PROJECT_ID="your-project-id"
SERVICE_ACCOUNT_EMAIL="your-service-account@your-project.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/serviceusage.serviceUsageConsumer"
```

### Option 3: Use a Service Account with More Permissions

If you have a service account with **Owner** or **Editor** role, it will have this permission automatically. However, for security best practices, use the minimal required role.

## Verify the Fix

After granting the role, wait 1-2 minutes for permissions to propagate, then trigger the GitHub Actions workflow again. The deployment should succeed.

## Additional Required Roles

Your service account should also have:
- **Cloud Functions Developer** (`roles/cloudfunctions.developer`) - to deploy functions
- **Service Account User** (`roles/iam.serviceAccountUser`) - to use service accounts
- **Storage Admin** (`roles/storage.admin`) - if using Cloud Storage

These are typically included when you create a Firebase service account.

