//
//  FileStore.swift
//  OpenCodeClient
//

import Foundation
import Observation

@Observable
final class FileStore {
    var sessionDiffs: [FileDiff] = []
    var selectedDiffFile: String?
    var fileTreeRoot: [FileNode] = []
    var fileStatusMap: [String: String] = [:]
    var expandedPaths: Set<String> = []
    var fileChildrenCache: [String: [FileNode]] = [:]
    var fileChildrenScope: FileChildrenScope?
    var fileChildrenLoadGeneration: [String: UInt64] = [:]
    var fileSearchQuery: String = ""
    var fileSearchResults: [String] = []
    var fileSearchGeneration: UInt64 = 0
    var fileSearchInFlight = false
    var fileSearchFailed = false
    var fileSearchError: String?
    var fileSearchOwner: HostRequestSnapshot?
    var fileSearchDirectory: String?
}

struct FileChildrenScope: Equatable {
    var host: HostRequestSnapshot
    var directory: String?
}
