//
//  CharacterSet+DB.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

extension CharacterSet {
    static let databaseAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="

        // TODO: Test thoroughly

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: generalDelimitersToEncode + subDelimitersToEncode)

        return allowed
    }()
}
