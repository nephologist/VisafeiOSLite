/**
    This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
    Copyright © Adguard Software Limited. All rights reserved.

    Adguard for iOS is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Adguard for iOS is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
*/

import Foundation
import Zip
import SQLite

protocol DefaultDatabaseManagerProtocol {
    
    // Checks if default.db file exists
    var defaultDbFileExists: Bool { get }
    
    // default.db schema version
    var defaultDbSchemaVersion: Int? { get }
    
    // Unarchives default.db and places it to the specified folder
    func updateDefaultDb() throws
    
    // Removes default.db file
    func removeDefaultDb() throws
}

final class DefaultDatabaseManager: DefaultDatabaseManagerProtocol {
    
    // MARK: - Public properties
    
    var defaultDbFileExists: Bool { fileManager.fileExists(atPath: defaultDbFileUrl.path) }
    
    lazy var defaultDbSchemaVersion: Int? = {
        guard let db = try? Connection(defaultDbFileUrl.path) else {
            return nil
        }
        
        let versionTable = Table("version")
        let versionColumn = Expression<Int>("schema_version")
        return try? db.pluck(versionTable)?.get(versionColumn)
    }()
        
    // MARK: - Private properties
    
    // default.db file URL
    private let defaultDbFileUrl: URL
    
    // Default database archive file name
    private let defaultDbArchiveFile = "default.db.zip"
    
    // Default database file name
    private let dbFile = "default.db"
    
    // URL where db files should be located
    private let dbContainerUrl: URL
    
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    init(dbContainerUrl: URL) {
        self.defaultDbFileUrl = dbContainerUrl.appendingPathComponent(dbFile)
        self.dbContainerUrl = dbContainerUrl
    }
    
    // MARK: - Public methods
    
    func updateDefaultDb() throws {
        guard let dbFileUrl = try getDefaultDbUnzippedData() else {
            Logger.logError("Failed to unarchive default.db")
            throw NSError(domain: "default.db.unarchive.failed", code: 1, userInfo: nil)
        }
        
        let _ = try fileManager.replaceItemAt(defaultDbFileUrl, withItemAt: dbFileUrl)
        try fileManager.removeItem(at: dbFileUrl)
    }
    
    func removeDefaultDb() throws {
        guard defaultDbFileExists else {
            Logger.logError("default.db file is missing, nothing to delete")
            return
        }
        
        try fileManager.removeItem(atPath: defaultDbFileUrl.path)
    }
    
    // MARK: - Private methods
    
    // Unarchives default database archive and returns an URL of default.db file
    private func getDefaultDbUnzippedData() throws -> URL? {
        guard let resourcesUrl = Bundle(for: type(of: self)).resourceURL else {
            return nil
        }
        let defaultDbArchiveUrl = resourcesUrl.appendingPathComponent(defaultDbArchiveFile)
        let targetDbFileUrl = resourcesUrl.appendingPathComponent(dbFile)
        try Zip.unzipFile(defaultDbArchiveUrl, destination: resourcesUrl, overwrite: true, password: nil)
        return targetDbFileUrl
    }
}
