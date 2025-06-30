//
//  NITokenCoder.swift
//  NearbyInteractionPermissions
//
//  Created by Ian Thomas on 10/17/24.
//

import Foundation
import NearbyInteraction

struct NITokenCoder {
    
    static func TokenToDataString(token: NIDiscoveryToken) -> String? {
        guard let data = TokenToData(token: token) else {
            return nil
        }
        return data.base64EncodedString()
    }
      
    private static func TokenToData(token: NIDiscoveryToken) -> Data? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            return data
        } catch {
            print("Error converting token to data: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func StringDataToToken(stringData: String) -> NIDiscoveryToken? {
    
        guard let data = Data(base64Encoded: stringData) else { return nil }
        do {
            let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data)
            return token
        } catch {
            print("Error converting data to token: \(error)")
            return nil
        }
    }
}
