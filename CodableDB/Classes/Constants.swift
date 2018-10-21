//
//  Constants.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

enum Constants {
    static let moduleName = "CodableDB"
}

func log(_ anyThing: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    print("[\(Constants.moduleName)]: " + anyThing.map { "\($0)" }.joined(separator: separator), terminator: terminator)
    #endif
}
