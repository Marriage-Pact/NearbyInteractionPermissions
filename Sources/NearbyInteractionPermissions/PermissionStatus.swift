//
//  PermissionStatus.swift
//  NearbyInteractionPermissions
//
//  Created by Ian Thomas on 6/29/25.
//

import Foundation

public enum PermissionStatus {
    
    /// The user has likely not been prompted to grant permission yet
    case unknown
    /// The user has granted permission
    case granted
    /// The user has directly denied permission
    case denied
    /// The user's current device is not supported
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
