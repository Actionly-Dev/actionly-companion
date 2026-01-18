# Accessibility Permissions Setup

## Required Setup in Xcode

To enable Actionly to execute keyboard shortcuts in other applications, you need to configure accessibility permissions.

### Step 1: Add Usage Description

1. Open your project in Xcode
2. Select the `actionly-companion` target
3. Go to the **Info** tab
4. Add a new key-value pair:
   - **Key**: `NSAppleEventsUsageDescription`
   - **Type**: String
   - **Value**: `Actionly needs to send keyboard events to execute shortcuts in other applications.`

Alternatively, if you have an Info.plist file, add this:

```xml
<key>NSAppleEventsUsageDescription</key>
<string>Actionly needs to send keyboard events to execute shortcuts in other applications.</string>
```

### Step 2: User Grants Permission

When the app first tries to execute shortcuts:

1. macOS will show a system prompt asking for Accessibility permission
2. User clicks "Open System Settings"
3. In **System Settings > Privacy & Security > Accessibility**:
   - Find "actionly-companion" in the list
   - Toggle it ON
4. Restart the app for changes to take effect

### Step 3: Verify Permissions

You can check if permissions are granted by:
- Opening Settings (Cmd+,) in the app
- Looking for the accessibility status indicator
- Or using the PermissionsView to check and request permissions

## How It Works

The app uses macOS Accessibility APIs to:
1. Track which app was active before Actionly opened
2. Send keyboard events to that application
3. Simulate key presses and text input

This requires explicit user permission for security reasons.

## Troubleshooting

**Permission not working?**
- Ensure the app is listed in System Settings > Privacy & Security > Accessibility
- Try toggling the permission OFF then ON again
- Restart the app after granting permission

**Still not working?**
- Check Console.app for any error messages
- Ensure you're running a signed build (Debug builds work fine for development)
