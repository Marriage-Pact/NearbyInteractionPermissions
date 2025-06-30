//
//  NearbyInteractionPermissions
//
//  Created by Ian Thomas on 6/27/25.
//

import Foundation
import UIKit
import NearbyInteraction

public class NIPermissionChecker: NSObject {
    
    enum CheckContext {
        case userTappedButton
        case passivePermissionTest
    }
    
    static let shared = NIPermissionChecker()
    
    /// When called this function either shows permissions dialog or takes users to the app's settings.
    /// The user is shown the permissions dialog if they have not been previously prompted to enable nearby interaction.
    public static func userTappedPermissionButton(completion: @escaping (PermissionStatus) -> Void) {
        shared.userTappedButton(completion: completion)
    }
    
    /// Will only show the permissions dialog if user hasn't been prompted before
    public static func checkPermissionIfUserHasAlreadyBeenPrompted(completion: @escaping (PermissionStatus) -> Void) {
        shared.checkPermissionIfUserHasAlreadyBeenPrompted(completion: completion)
    }
    
    // MARK: - Private
    
    private var niSession: NISession?
    private var permissionStatus: PermissionStatus = .unknown
    private var completion: ((PermissionStatus) -> Void)?
    
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
        
        DispatchQueue.main.async { [weak self] in
            
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
    
    private func checkPermissionIfUserHasAlreadyBeenPrompted(completion: @escaping (PermissionStatus) -> Void) {
        if UserDefaults.standard.hasBeenPromptedForNI {
            print("🔍 User has already been prompted for NI permission - checking current permission state")
            checkPermission(context: .passivePermissionTest, completion: completion)
        } else {
            print("🔍 User has not been prompted yet for NI, stoping check")
            completion(.unknown)
        }
    }
    
    private func userTappedButton(completion: @escaping (PermissionStatus) -> Void) {
        print("🔍 User tapped NI permission button")

        /// When the user taps on the NI button and then denies, that's the `first` tap.
        /// If permission is denied and the users taps the button a `second` time, then go to app settings settings.
        if permissionStatus == .denied && UserDefaults.standard.hasBeenPromptedForNI {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                      options: [:],
                                      completionHandler: nil)
        } else {
            checkPermission(context: .userTappedButton, completion: completion)
        }
    }
    
    private func checkPermission(context: CheckContext, completion: @escaping (PermissionStatus) -> Void) {
        
        print("🔍 NIPermissionChecker.shared: Starting permission check (context: \(context))")
        
        // Clean up any existing session first
        if niSession != nil {
            print("🧹 Cleaning up existing session before starting new one")
            niSession?.invalidate()
            niSession = nil
        }
        
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            print("❌ Device doesn't support NI")
            completion(.notSupported)
            return
        }
        
        self.completion = completion
        
        // Create a test session
        niSession = NISession()
        niSession?.delegate = self
        
        guard let session = niSession else {
            print("❌ Failed to create NISession")
            completion(.unknown)
            return
        }
        
        // Start a test session that will fail quickly and reveal permission status
        guard let token = session.discoveryToken else {
            print("❌ No discovery token available")
            completion(.unknown)
            cleanup()
            return
        }
        print("User's latest discovery token (shortened): \(token.keyTokenElements)")

        let config = NINearbyPeerConfiguration(peerToken: token)
        session.run(config)
        
        // Mark as prompted when user taps button
        if context == .userTappedButton {
            UserDefaults.standard.markUserAsPromptedForNI()
        }
        
        /// When asking permission for the first time, we don't want to immediately invalidate the session because the permission prompt has just appeared and the user has not had time to grant or deny permission. If we don't handle this case, then the app will falsely believe that permission has been granted, when it has not.
        /// Wait a half second incase the permissions view is now appearing, and then check the applicationState to see if a permissions prompt is likely showing, i.e. the application state is `inactive`. If one is showing, don't invalidate the session, because invalidating at this point would result in a false positive.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if UIApplication.shared.applicationState == .active {
                // Invalidate the session to determine latest status
                session.invalidate()
                session.run(config)
            } else {
                /// The user is currently being asked for permission, don't terminate session yet.
                /// If user denies the permission prompt, we get a delegate callback immediately.
                /// If they grant permission, then we update the status in `appDidBecomeActive`.
            }
        }
    }
    
    private func cleanup() {
        niSession?.invalidate()
        niSession = nil
        completion = nil
    }
}

extension NIPermissionChecker: NISessionDelegate {
    
    /// Once the session has errored, we can determine the permission status.
    public func session(_ session: NISession, didInvalidateWith error: Error) {
        
        guard let niError = error as? NIError else {
            print("❌ Non-NI error: \(error.localizedDescription)")
            permissionStatus = .unknown
            completion?(.unknown)
            return
        }
        
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
            // but the session failed because we used this device's own token
            permissionStatus = .granted
            completion?(.granted)
        default:
            print("ℹ️ Other NI error: \(niError.localizedDescription)")
            // For our test case, other errors likely mean permission is granted
            // but the session failed for other reasons
            permissionStatus = .granted
            completion?(.granted)
        }
        
        cleanup()
    }
    
    public func sessionWasSuspended(_ session: NISession) {
        // Permission was likely granted but session suspended
        permissionStatus = .granted
        completion?(.granted)
        cleanup()
    }
    
    public func sessionSuspensionEnded(_ session: NISession) {
        // Permission was likely granted
        permissionStatus = .granted
        completion?(.granted)
        cleanup()
    }
    
    public func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // This shouldn't happen in our test case, but if it does, permission is granted
        permissionStatus = .granted
        completion?(.granted)
        cleanup()
    }
}
