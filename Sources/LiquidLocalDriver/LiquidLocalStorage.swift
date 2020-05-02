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

    func resolve(key: String) -> String {
        self.baseUrl.appendingPathComponent(key).absoluteString
    }
    
    private var basePath: URL {
        let url = URL(fileURLWithPath: self.configuration.publicPath)
        return url.appendingPathComponent(self.configuration.workDirectory)
    }
    
    private var baseUrl: URL {
        let url = URL(string: self.configuration.publicUrl)!
        return url.appendingPathComponent(self.configuration.workDirectory)
    }

    func upload(key: String, data: Data) -> EventLoopFuture<String> {
        do {
            let fileUrl = self.basePath.appendingPathComponent(key)
            let location = fileUrl.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: location,
                                                    withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o644])

            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            return self.fileio.openFile(path: fileUrl.path,
                                        mode: .write,
                                        flags: .allowFileCreation(posixMode: 0o644),
                                        eventLoop: self.context.eventLoop)
                //            .flatMapErrorThrowing { error in
                //                throw "unable to open file \(path)"
                //            }
                .flatMap { handle in
                    return self.fileio.write(fileHandle: handle,
                                             buffer: buffer,
                                             eventLoop: self.context.eventLoop)
                        .flatMapThrowing { _ in
                            try handle.close()
                            return self.resolve(key: key)
                    }
            }
        }
        catch {
            return self.context.eventLoop.makeFailedFuture(error)
        }
    }

    func delete(key: String) -> EventLoopFuture<Void> {
        do {
            let fileUrl = self.basePath.appendingPathComponent(key)
            try FileManager.default.removeItem(atPath: fileUrl.path)
            return self.context.eventLoop.makeSucceededFuture(())
        }
        catch {
            return self.context.eventLoop.makeFailedFuture(error)
        }
    }
}


