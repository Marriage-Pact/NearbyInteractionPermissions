//
//  NITokenAnalysis.swift
//
//  Created by Ian Thomas on 10/31/24.
//

import Foundation
import NearbyInteraction

extension NIDiscoveryToken {
    
    public var keyTokenElements: String {
        guard let tokenAsString = NITokenCoder.TokenToDataString(token: self) else {
            return "Couldn't do TokenToDataString"
        }
        return NITokenAnalysis.ExtractKeyPartOfToken(tokenAsString)
    }
}

struct NITokenAnalysis {
    
    static func ExtractKeyPartOfToken(_ token: String) -> String {
        let array = SplitBase64StringIntoParts(token, partSize: 8)
        return JoinKeyTokenParts(arrayOfTokens: array)
    }
    
    private static func SplitBase64StringIntoParts(_ string: String, partSize: Int) -> [String] {
        var parts: [String] = []
        var startIndex = string.startIndex
        
        while startIndex < string.endIndex {
            let endIndex = string.index(startIndex, offsetBy: partSize, limitedBy: string.endIndex) ?? string.endIndex
            let substring = String(string[startIndex..<endIndex])
            parts.append(substring)
            startIndex = endIndex
        }
        
        return parts
    }
    
    private static func JoinKeyTokenParts(arrayOfTokens: [String]) -> String {
        
        var concatenatedString = ""
        
        for i in 26..<30 {
            let slice = arrayOfTokens[i]
            concatenatedString += slice
            if let slice = arrayOfTokens[safe: i] {
                concatenatedString += slice
            }
        }
        
        return concatenatedString
    }
}

extension Collection {
    /// Returns the element at the specified index if it's within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
