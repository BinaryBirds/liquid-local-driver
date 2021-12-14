//
//  LiquidLocalStorage.swift
//  LiquidLocalStorageDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import Foundation

struct LiquidLocalStorage: FileStorage {
    let fileio: NonBlockingFileIO
    let configuration: LiquidLocalStorageConfiguration
    let context: FileStorageContext
    
    /// default posix mode used to create files and directories
    let posixMode: mode_t
    
    init(fileio: NonBlockingFileIO, configuration: LiquidLocalStorageConfiguration, context: FileStorageContext, posixMode: mode_t = 0o744) {
        self.fileio = fileio
        self.configuration = configuration
        self.context = context
        self.posixMode = posixMode
    }
    
    // MARK: - private

    private var basePath: URL {
        URL(fileURLWithPath: configuration.publicPath).appendingPathComponent(configuration.workDirectory)
    }
    
    private var baseUrl: URL {
        URL(string: configuration.publicUrl)!.appendingPathComponent(configuration.workDirectory)
    }

    /// creates the entire directory structure with the necessary posix permissions
    private func createDir(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: posixMode])
    }

    // MARK: - api

    func resolve(key: String) -> String {
        baseUrl.appendingPathComponent(key).absoluteString
    }

    func upload(key: String, data: Data) async throws -> String {
        let fileUrl = basePath.appendingPathComponent(key)
        let location = fileUrl.deletingLastPathComponent()
        try createDir(at: location)

        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)

        return try await fileio.openFile(path: fileUrl.path, mode: .write, flags: .allowFileCreation(posixMode: posixMode), eventLoop: context.eventLoop)
        .flatMap { handle in
            fileio.write(fileHandle: handle, buffer: buffer, eventLoop: context.eventLoop).flatMapThrowing { _ in
                try handle.close()
                return resolve(key: key)
            }
        }.get()
    }

    func createDirectory(key: String) async throws {
        let dirUrl = basePath.appendingPathComponent(key)
        try createDir(at: dirUrl)
    }

    func getObject(key source: String) async throws -> Data? {
        let sourceUrl = basePath.appendingPathComponent(source)
        return try Data(contentsOf: sourceUrl)
    }

    func list(key: String?) async throws -> [String] {
        let dirUrl = basePath.appendingPathComponent(key ?? "")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: dirUrl.path, isDirectory: &isDir), isDir.boolValue {
            let files = try FileManager.default.contentsOfDirectory(atPath: dirUrl.path)
            return files
        }
        /// it was a file... files don't have children, so we return an empty array.
        return []
    }
    
    func copy(key source: String, to destination: String) async throws -> String {
        let exists = await exists(key: source)
        guard exists else {
            throw LiquidError.keyNotExists
        }
        try await delete(key: destination)
        let sourceUrl = basePath.appendingPathComponent(source)
        let destinationUrl = basePath.appendingPathComponent(destination)
        let location = destinationUrl.deletingLastPathComponent()
        try createDir(at: location)
        try FileManager.default.copyItem(at: sourceUrl, to: destinationUrl)
        return resolve(key: destination)
    
    }

    func move(key source: String, to destination: String) async throws -> String {
        let url = try await copy(key: source, to: destination)
        try await delete(key: source)
        return url
    }

    func delete(key: String) async throws {
        let exists = await exists(key: key)
        guard exists else {
            return
        }
        let fileUrl = basePath.appendingPathComponent(key)
        try FileManager.default.removeItem(atPath: fileUrl.path)
    }

    func exists(key: String) async -> Bool {
        let fileUrl = basePath.appendingPathComponent(key)
        return FileManager.default.fileExists(atPath: fileUrl.path)
    }
}


