//
//  Errors.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

public enum CodableDBError: Error, Equatable {
    case noMoreRowAvailable
    case preparationFailed(sqliteError: String)
    case couldNotFindDatabase(atPath: URL)
    case incorrectReturnForCommand
    case unsupportedType
    case unexpectedReturnCode(Int32)
    case errorneousReturnCode(ReturnCode)
    case inconsistentData(description: String)
    case currentlyUnsupportedAction
}
