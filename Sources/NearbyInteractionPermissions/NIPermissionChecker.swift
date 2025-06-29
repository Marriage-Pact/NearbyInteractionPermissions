//
//  NearbyInteractionPermissions
//
//  Created by Ian Thomas on 6/27/25.
//

import Foundation
import UIKit
import NearbyInteraction

public class NIPermissionChecker: NSObject {
    #warning("add directing user to settings if denied and the user taps again")
    
    public enum PermissionStatus {
        /// The user has likely not been prompted to grant permission yet
        case unknown
        /// The user has granted permission
        case granted
        case denied
        case notSupported
        
        public var displayString: String {
            switch self {
            case .unknown:
                "Unknown"
            case .granted:
                "Granted"
            case .denied:
                "Denied"
            case .notSupported:
                "Not supported on this device"
            }
        }
    }
    
    enum CheckContext {
        case userTappedButton
        case passiveStartupPermissionTest
        case oneTimeCheck
    }
    
    static let shared = NIPermissionChecker()
    
    private var niSession: NISession?
    private var permissionStatus: PermissionStatus = .unknown
    private var completion: ((PermissionStatus) -> Void)?
    private var context: CheckContext = .oneTimeCheck
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    @objc private func appDidBecomeActive() {
        print("appDidBecomeActive")
        DispatchQueue.main.async { [weak self] in
            print("self?.niSession \(self?.niSession)")
            guard let self else { return }
            /// If there's a token, then there's a session that was running before the app became inactive
            /// In that case, invalidate the session but then run it again with the same configuration as before
            /// This will always invoke `session: NISession, didInvalidateWith: Error`
            /// and we can use the `Error` in there to determine the permission status
            guard let token = self.niSession?.discoveryToken else { return }
            
            self.niSession?.invalidate()
            let config = NINearbyPeerConfiguration(peerToken: token)
            self.niSession?.run(config)
        }
    }
    
    /// The user is tapping permission button.
    /// Shows permissions dialog or takes users to the app's settings
    public static func userTappedPermissionButton(completion: @escaping (PermissionStatus) -> Void) {
        shared.userTappedButton(completion: completion)
    }
    
    /// Will only show the permissions dialog if user hasn't been prompted before
    public static func checkPermissionStatusIfNotPromptedBefore(completion: @escaping (PermissionStatus) -> Void) {
        shared.checkPermissionIfNotPromptedBefore(completion: completion)
    }
    
   
    
    private func checkPermissionIfNotPromptedBefore(completion: @escaping (PermissionStatus) -> Void) {
        if UserDefaults.standard.shouldTestNIPermissionOnStartup {
            print("🔍 User has already been prompted for NI permission - testing current state")
            checkPermission(context: .passiveStartupPermissionTest, completion: completion)
        } else {
            print("🔍 User has not been prompted yet for NI - will wait for user action")
            completion(.unknown)
        }
    }
    
    private func userTappedButton(completion: @escaping (PermissionStatus) -> Void) {
        /// When the user taps on the NI button and then denies, that's tap one
        /// When they tap on it the second time, then go to settings.
        if permissionStatus == .denied && UserDefaults.standard.hasBeenPromptedForNI {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                      options: [:],
                                      completionHandler: nil)
        } else {
            checkPermission(context: .userTappedButton, completion: completion)
        }
        print("🔍 User tapped NI permission button")
    }
    
    private func checkPermission(context: CheckContext, completion: @escaping (PermissionStatus) -> Void) {
        self.context = context
        
        print("🔍 NIPermissionChecker.shared: Starting permission check (context: \(context))")
        
        // Clean up any existing session first
        if niSession != nil {
            print("🧹 Cleaning up existing session before starting new one")
            niSession?.invalidate()
            niSession = nil
        }
        
        // Check if device supports NI first
        let capabilities = NISession.deviceCapabilities
        print("🔍 Device capabilities:")
        print("   - supportsPreciseDistanceMeasurement: \(capabilities.supportsPreciseDistanceMeasurement)")
        print("   - supportsDirectionMeasurement: \(capabilities.supportsDirectionMeasurement)")
        
        guard capabilities.supportsPreciseDistanceMeasurement else {
            print("❌ Device doesn't support NI")
            completion(.notSupported)
            return
        }
        
        self.completion = completion
        
        // Create a test session
        print("🔍 Creating NISession...")
        niSession = NISession()
        niSession?.delegate = self
        
        guard let session = niSession else {
            print("❌ Failed to create NISession")
            completion(.unknown)
            return
        }
        
        print("✅ NISession created: \(session)")
        print("✅ Delegate set to: \(self)")
        
        
        // Start a test session that will fail quickly and reveal permission status
        if let token = session.discoveryToken {
            print("✅ Discovery token available: \(token)")
            let config = NINearbyPeerConfiguration(peerToken: token)
            
            let tokenString = NITokenCoder.TokenToDataString(token: token)
            print("this user latest discovery token short: \(token.keyTokenElements) Long: \(String(describing: tokenString)))")
            
            print("🔍 About to call session.run() - this should trigger permission dialog")
            session.run(config)
            print("✅ session.run() called")
            
          
            // Mark as prompted when user taps button
            if context == .userTappedButton {
                UserDefaults.standard.markUserAsPromptedForNI()
                print("🔍 Marked user as having been prompted for NI permission")
            }
        
            /// When asking permission for the first time, we don't want to imedaitly invalidate the session because the user has not had time to grant or denie permissions. If we dont handle this case then the app will falsely belive that permission has been granted, when it has not. Avoid that false positive.
            /// Wait a halk second incase the permissions view is now appearing, and then check the applicationState to see if a permossions prompt is likely showing. if one is showing, keep the session alive, because invaludating at this point would result in a false positive.
//            if self.permissionStatus != .unknown {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) { [weak self] in

//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { [weak self] in
                    // TODO: if can pause and resume, then granted permissions!
                    //            session.pause()
                    if UIApplication.shared.applicationState == .active {
                        print("state is active, invaluidate at once!")
                        session.invalidate()
                        
                        //            if self?.permissionStatus != .denied {
                        session.run(config)
                    } else {
                        print("User is being asked for permission, don't terminate session yet")
                        // If user denies the permission promt, we get the callback
                    }
                }
//            }
            
            // TODO: call clean later, it kills the completion call
            //self?.cleanup()
//        }
        
        } else {
            print("❌ No discovery token available")
            completion(.unknown)
            cleanup()
        }
    }
    
    private func cleanup() {
        print("🧹 Cleaning up NIPermissionChecker")
        
        niSession?.invalidate()
        niSession = nil
        completion = nil
    }
}

extension NIPermissionChecker: NISessionDelegate {
    
    public func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        print("✅ didUpdate nearbyObjects (unexpected for self-token test)")
        // This shouldn't happen in our test case, but if it does, permission is granted
        permissionStatus = .granted
        completion?(.granted)
        cleanup()
    }
    
    public func session(_ session: NISession, didInvalidateWith error: Error) {
        print("📱 Session invalidated with error: \(error)")
        
        if let niError = error as? NIError {
            print("📱 NIError code: \(niError.code.rawValue)")
            switch niError.code {
            case .userDidNotAllow:
                print("🚫 User denied NI permission")
                permissionStatus = .denied
                completion?(.denied)
            case .unsupportedPlatform:
                print("❌ Unsupported platform")
                permissionStatus = .notSupported
                completion?(.notSupported)
            case .invalidConfiguration:
                print("⚙️ Invalid configuration (expected for self-token test)")
                // For our test case, this usually means permission is granted
                // but the session failed because we used the same token
                permissionStatus = .granted
                completion?(.granted)
            default:
                print("ℹ️ Other NI error: \(niError.localizedDescription)")
                // For our test case, other errors likely mean permission is granted
                // but the session failed for other reasons
                permissionStatus = .granted
                completion?(.granted)
            }
        } else {
            print("❌ Non-NI error: \(error.localizedDescription)")
            permissionStatus = .unknown
            completion?(.unknown)
        }
        cleanup()
    }
    
    public func sessionWasSuspended(_ session: NISession) {
        print("⏸️ Session was suspended")
        // Permission likely granted but session suspended
        permissionStatus = .granted
        completion?(.granted)
        cleanup()
    }
    
    public func sessionSuspensionEnded(_ session: NISession) {
        print("▶️ Session suspension ended")
        // Permission granted
        permissionStatus = .granted
        completion?(.granted)
        cleanup()
    }
}
