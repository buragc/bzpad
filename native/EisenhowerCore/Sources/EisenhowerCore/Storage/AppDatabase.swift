import Foundation
import GRDB

/// The single SQLite database for the app.
/// Opened once at launch and shared as an actor-isolated singleton.
///
/// WAL mode is enabled by default in GRDB when using a DatabasePool.
/// Encryption (SQLCipher) is not included in the open-source GRDB; to enable it,
/// swap `DatabasePool` for the SQLCipher variant and pass the encryption key.
public final class AppDatabase: Sendable {

    public static let shared: AppDatabase = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir  = urls[0].appendingPathComponent("bzpad", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("bzpad.sqlite")
        return try! AppDatabase(url: dbURL)
    }()

    public let pool: DatabasePool

    public init(url: URL) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            // WAL mode for concurrent reads while writing
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            // Synchronous NORMAL — safe with WAL, better performance than FULL
            try db.execute(sql: "PRAGMA synchronous=NORMAL")
        }

        pool = try DatabasePool(path: url.path, configuration: config)

        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(pool)
    }

    /// Used for isolated test databases. Creates a unique temp file per call.
    /// DatabasePool requires a real file (WAL mode is file-based), so we use a
    /// unique temp path rather than :memory:.
    public static func makeEmpty() throws -> AppDatabase {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bzpad-test-\(UUID().uuidString).sqlite")
        return try AppDatabase(url: url)
    }
}
