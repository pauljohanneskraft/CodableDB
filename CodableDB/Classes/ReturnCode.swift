//
//  ReturnCode.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

public enum ReturnCode: Int32 {
    case ok = 0
    case error = 1
    case `internal` = 2
    case permission = 3
    case abort = 4
    case busy = 5
    case locked = 6
    case mallocFail = 7
    case readOnly = 8
    case interrupt = 9
    case io = 10
    case corrupt = 11
    case notFound = 12
    case full = 13
    case cantOpen = 14
    case `protocol` = 15
    case empty = 16
    case schema = 17
    case tooBig = 18
    case constraint = 19
    case mismatch = 20
    case misuse = 21
    case noLFS = 22
    case authorization = 23
    case format = 24
    case range = 25
    case notDatabase = 26
    case notice = 27
    case warning = 28
    case row = 100
    case done = 101
}
