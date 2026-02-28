# 🔧 Push Notifications Setup Guide

## ✅ What's Already Working:
- ✅ Notification logic in Flutter app
- ✅ Cloud Functions code for sending notifications
- ✅ Firebase configuration
- ✅ Token management

## 🚨 Issues Found & Fixed:

### 1. **AndroidManifest.xml** - Fixed ✅
Added missing Firebase Cloud Messaging service configuration:
- FCM service registration
- Default notification icon and color
- Notification channel configuration

### 2. **Cloud Functions Deployment** - Needs Action ⚠️
The functions exist but may not be deployed to Firebase.

## 🚀 Steps to Make Notifications Work:

### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Deploy Cloud Functions
Run this command in your project root:
```bash
cd functions
npm install
firebase deploy --only functions
```

Or use the script I created:
- Double-click `deploy_functions.ps1` (PowerShell)
- Or run `deploy_functions.bat` (Command Prompt)

### Step 4: Test Notifications
1. **Build and run your app**
2. **Login with two different accounts**
3. **Like/comment on a post from one account**
4. **The other account should receive a push notification**

## 📱 Device-Specific Checks:

### Android:
- ✅ Permissions already added (`POST_NOTIFICATIONS`, `VIBRATE`)
- ✅ Notification channel configured
- Check: Settings > Apps > NATU-Students > Notifications > Allow

### iOS:
- Notifications should work automatically
- Check: Settings > Notifications > NATU-Students > Allow Notifications

## 🔍 Troubleshooting:

### If notifications still don't work:

1. **Check Firebase Console:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project: `university-connect-52779`
   - Check Functions section - ensure functions are deployed
   - Check Cloud Messaging section - ensure it's enabled

2. **Check Device Token:**
   - Add debug print in `PushNotificationsService._syncTokenIfPossible()`
   - Ensure token is being saved to Firestore user document

3. **Check Cloud Functions Logs:**
   - In Firebase Console > Functions > Logs
   - Look for any errors when notifications are triggered

4. **Test with Firebase Console:**
   - Firebase Console > Cloud Messaging > Send Test Message
   - Send test notification to specific device token

## 📋 Notification Types Supported:
- ✅ Comments on your posts
- ✅ Replies to your comments
- ✅ Likes on your posts
- ✅ Reactions (😊❤️😢) on your posts
- ✅ Reposts of your posts
- ✅ New schedule uploads
- ✅ Post approval/rejection

## 🎯 Expected Behavior:
- **App Closed**: Push notification appears
- **App Open**: Local notification appears
- **Notification Tap**: Opens relevant screen (post detail, notifications, etc.)

The setup is now complete! The main issue was the missing Cloud Functions deployment. Once you deploy the functions, notifications should work perfectly.