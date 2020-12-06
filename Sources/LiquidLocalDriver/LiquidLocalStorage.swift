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
    let posixMode: mode_t
    
    init(fileio: NonBlockingFileIO, configuration: LiquidLocalStorageConfiguration, context: FileStorageContext, posixMode: mode_t = 0o744) {
        self.fileio = fileio
        self.configuration = configuration
        self.context = context
        self.posixMode = posixMode
    }

    private var basePath: URL {
        let url = URL(fileURLWithPath: configuration.publicPath)
        return url.appendingPathComponent(configuration.workDirectory)
    }
    
    private var baseUrl: URL {
        let url = URL(string: configuration.publicUrl)!
        return url.appendingPathComponent(configuration.workDirectory)
    }

    /// creates the entire directory structure with the necessary posix permissions
    private func createDir(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: posixMode])
    }

    // MARK: - api

    func resolve(key: String) -> String { baseUrl.appendingPathComponent(key).absoluteString }

    func upload(key: String, data: Data) -> EventLoopFuture<String> {
        do {
            let fileUrl = basePath.appendingPathComponent(key)
            let location = fileUrl.deletingLastPathComponent()
            try createDir(at: location)

            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            return fileio.openFile(path: fileUrl.path, mode: .write, flags: .allowFileCreation(posixMode: posixMode), eventLoop: context.eventLoop)
            .flatMap { handle in
                fileio.write(fileHandle: handle, buffer: buffer, eventLoop: context.eventLoop).flatMapThrowing { _ in
                    try handle.close()
                    return resolve(key: key)
                }
            }
        }
        catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }

    func createDirectory(key: String) -> EventLoopFuture<Void> {
        do {
            let dirUrl = basePath.appendingPathComponent(key)
            try createDir(at: dirUrl)
            return context.eventLoop.makeSucceededFuture(())
        }
        catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }

    func list(key: String?) -> EventLoopFuture<[String]> {
        let dirUrl = basePath.appendingPathComponent(key ?? "")
        do {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dirUrl.path, isDirectory: &isDir), isDir.boolValue {
                let files = try FileManager.default.contentsOfDirectory(atPath: dirUrl.path)
                return context.eventLoop.makeSucceededFuture(files)
            }
            /// it was a file... files don't have children, so we return an empty array.
            return context.eventLoop.makeSucceededFuture([])
        }
        catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }

    func delete(key: String) -> EventLoopFuture<Void> {
        do {
            let fileUrl = basePath.appendingPathComponent(key)
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                try FileManager.default.removeItem(atPath: fileUrl.path)
            }
            return context.eventLoop.makeSucceededFuture(())
        }
        catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }

    func exists(key: String) -> EventLoopFuture<Bool> {
        let fileUrl = basePath.appendingPathComponent(key)
        let exists = FileManager.default.fileExists(atPath: fileUrl.path)
        return context.eventLoop.makeSucceededFuture(exists)
    }
}


