//
//  String+Ohia.swift
//  Ohia
//
//  Created by iain on 26/10/2023.
//

import Foundation

extension URL {
    var abbreviatingWithTildeInPath: String {
        // NSString.abbreviatingWithTildeInPath doesn't work for sandboxed apps
        // as /Users/<user>/ is not the sandboxed home directory
        // https://developer.apple.com/documentation/foundation/nsstring/1407943-abbreviatingwithtildeinpath

        guard pathComponents.count > 3, 
                pathComponents[1] == "Users" else {
            return path(percentEncoded: false)
        }
        
        // / + pathComponent[1] + / + pathComponents[2]
        let homeDirLength = 2 + pathComponents[1].count + pathComponents[2].count
        let path = path(percentEncoded: false)
        let abbreviatedPath = path.suffix(path.count - homeDirLength)
        return "~" + abbreviatedPath
    }
}
