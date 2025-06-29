//
//  UserDefaults Extension.swift
//
//  Created by Ian Thomas on 6/27/25.
//

import Foundation

extension UserDefaults {
    
    private enum NIKeys {
        static let prompted = "promptedForNearbyInteractionFramework"
        static let tapCount = "countTimesTappedNIBtn"
    }
    
    // MARK: - NI Permission Tracking
    
    var hasBeenPromptedForNI: Bool {
        get { bool(forKey: NIKeys.prompted) }
        set { set(newValue, forKey: NIKeys.prompted) }
    }
    
    // MARK: - Convenience Methods
    
    func markUserAsPromptedForNI() {
        hasBeenPromptedForNI = true
    }
    
    var shouldTestNIPermissionOnStartup: Bool {
        return hasBeenPromptedForNI
    }
}
