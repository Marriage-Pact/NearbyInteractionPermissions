# NearbyInteractionPermissions

A Swift package that provides a simple way to check and request Nearby Interaction permissions on iOS devices.

## Why This Package is Necessary

Apple's Nearby Interaction framework lacks a direct API to check permission status, unlike other system permissions (camera, notifications, location, etc.). This creates several challenges for developers:

### The Challenges
- 🔇 **No Silent Permission Check**: There's no way to silently determine if a user has granted or denied Nearby Interaction permission in the background
- 🎫 **Token Dependency**: The only way to check permissions is to attempt to connect to another device, but this requires a valid device token from another device
- 🚨 **Intrusive Permission Prompts**: Starting an NI session triggers the permission prompt at potentially inappropriate times, disrupting user experience
- 🔄 **Complex Permission Flow**: Developers must manage the entire nearby interaction session lifecycle just to determine permission status

### Without This Package
Without this package, checking NI permissions required:
1. Obtaining a valid token from another device
2. Creating a `NINearbyPeerConfiguration` with that token
3. Running the configuration and starting a session
4. Only then receiving callbacks about permission denial

The previous approach is cumbersome and requires having multiple devices available for testing.

## How This Package Works

This package uses an innovative approach to solve the permission detection problem:

### 💡 The Insight
1. 🎭 **Self-Token**: Create a "decoy" Nearby Interaction session using the current device's own discovery token
2. ⚡ **Intentional Invalidation**: Invalidate that session immediately to trigger error callbacks
3. 🔍 **Error Analysis**: Analyze the resulting error to determine permission status:
   - ❌ `userDidNotAllow` error = Permission denied
   - ✅ `invalidConfiguration` error = Permission granted (session failed due to self-token configuration, not permission)

### Technical Implementation
The package creates a temporary `NISession`, starts it with the device's own token (which will always fail), and uses the failure reason to determine the actual permission state. This workaround provides instant permission status without requiring tokens from other NI devices.

## Installation

### Swift Package Manager

Add FullSpeedVStack to your project through Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/Marriage-Pact/NearbyInteractionPermissions`
3. Select your desired version

## Configuration

### Required: Add Usage Description to Info.plist

**Important**: You must add the `NSNearbyInteractionUsageDescription` key to your app's `Info.plist` file, or the permission prompt will not appear.

```xml
<key>NSNearbyInteractionUsageDescription</key>
<string>This app uses Nearby Interaction to connect with nearby devices.</string>
```

Replace the description text with an appropriate explanation of how your app uses Nearby Interaction.

## Usage

### Import the Package
```swift
import NearbyInteractionPermissions
```

### SwiftUI Example
Use the provided `Sources/Example/NearbyInteractionPermissionsView` for a complete UI solution:

The view displays:
- Current permission status
- A button to request permissions
- Automatic status updates when the app becomes active

<img src="https://github.com/user-attachments/assets/ea569b3b-e3d5-437c-b0ef-6ed310ce3617" alt="NearbyInteractionPermissions Demo" height="400">

### Custom Implementation

#### 1. Active Permission Request
Request NI permissions with appropriate handling for first-time users:

```swift
// This will show the permission prompt if it's the first time,
// or take users to App Settings if they previously denied
NIPermissionChecker.userTappedPermissionButton { status in
  switch status {
  case .granted:
        print("Permission granted - ready to use NI")
        // Initialize your NI features
    case .denied:
        print("Permission denied - show alternative UI")
        // Show fallback functionality
    case .notSupported:
        print("Device doesn't support Nearby Interaction")
        // Hide NI features entirely
    case .unknown:
        print("User hasn't been prompted yet")
        // Show permission request UI
    }
}
```

#### 2. Passive Permission Check
Check permission status without showing the NI permission prompt:

```swift
import NearbyInteractionPermissions

// This will only check permissions if the user has been previously prompted
NIPermissionChecker.checkPermissionIfUserHasAlreadyBeenPrompted { status in
    switch status { 
        // Same `status` return as above
    }
}
```

## Best Practices

### When to Use Each Method

**Active Request (`userTappedPermissionButton`)**:
- User explicitly taps a "Enable NI" button or user attempts to use an NI feature for the first time
- If the user denied permissions, take them to the app’s settings

**Passive Check (`checkPermissionIfUserHasAlreadyBeenPrompted`)**:
- App launch to set up initial UI state
- Checks when app enters the foreground

## Limitations

### Technical Limitations
- **iOS Version**: Requires iOS 16.0+
- **Device Compatibility**: Only works on devices that support Nearby Interaction (iPhone 11 and later with U1 chip. No iPads)
- **Apple Changes**: Future iOS updates could modify the self-discovery token behavior this package relies on

### Configuration Limitations
- **Airplane Mode**: If the device is in airplane mode, `sessionWasSuspended` may be called immediately, potentially providing incorrect permission status

### Permission Prompt Not Appearing?
- **Usage Description Required**: The permission prompt will not appear without `NSNearbyInteractionUsageDescription` in Info.plist
