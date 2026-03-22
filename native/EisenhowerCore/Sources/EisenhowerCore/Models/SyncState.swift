import Foundation

public struct SyncState: Codable, Sendable, Equatable {
    public var lastCloudKitSync: Date?
    public var lastGitSync: Date?
    public var gitRepoURL: String?
    public var gitBranch: String
    public var pendingChanges: Int
    public var isSyncing: Bool

    public init(
        lastCloudKitSync: Date? = nil,
        lastGitSync: Date? = nil,
        gitRepoURL: String? = nil,
        gitBranch: String = "main",
        pendingChanges: Int = 0,
        isSyncing: Bool = false
    ) {
        self.lastCloudKitSync = lastCloudKitSync
        self.lastGitSync = lastGitSync
        self.gitRepoURL = gitRepoURL
        self.gitBranch = gitBranch
        self.pendingChanges = pendingChanges
        self.isSyncing = isSyncing
    }
}
