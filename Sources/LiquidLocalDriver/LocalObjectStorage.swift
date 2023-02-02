//
//  LocalFileStorageDriver.swift
//  LiquidLocalDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import Foundation
import NIO
import LiquidKit

struct LocalObjectStorage {

    let fileio: NonBlockingFileIO
    let byteBufferAllocator: ByteBufferAllocator
    let context: ObjectStorageContext
    
    init(
        fileio: NonBlockingFileIO,
        byteBufferAllocator: ByteBufferAllocator,
        context: ObjectStorageContext
    ) {
        self.fileio = fileio
        self.byteBufferAllocator = byteBufferAllocator
        self.context = context
    }
}

private extension LocalObjectStorage {
    
    var configuration: LocalObjectStorageConfiguration {
        context.configuration as! LocalObjectStorageConfiguration
    }
    
    var posixMode: mode_t {
        configuration.posixMode
    }

    var basePath: URL {
        URL(fileURLWithPath: configuration.publicPath)
            .appendingPathComponent(configuration.workDirectory)
    }

    var baseUrl: URL {
        URL(string: configuration.publicUrl)!
            .appendingPathComponent(configuration.workDirectory)
    }

    func createDir(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [
                .posixPermissions: posixMode
            ])
    }
}

extension LocalObjectStorage: ObjectStorage {
    
    func createChecksumCalculator() -> LiquidKit.ChecksumCalculator {
        CRC32()
    }

    func resolve(
        key: String
    ) -> String {
        baseUrl.appendingPathComponent(key).absoluteString
    }

    func upload(
        key: String,
        buffer: ByteBuffer,
        checksum: String?
    ) async throws {
        let fileUrl = basePath.appendingPathComponent(key)
        let location = fileUrl.deletingLastPathComponent()
        try createDir(at: location)
        
        return try await fileio.openFile(
            path: fileUrl.path,
            mode: .write,
            flags: .allowFileCreation(posixMode: posixMode),
            eventLoop: context.eventLoop
        )
        .flatMap { handle in
            fileio.write(
                fileHandle: handle,
                buffer: buffer,
                eventLoop: context.eventLoop
            )
            .flatMapThrowing { _ in
                try handle.close()
            }
        }
        .get()
    }

    func create(
        key: String
    ) async throws {
        let dirUrl = basePath.appendingPathComponent(key)
        try createDir(at: dirUrl)
    }

    func download(
        key source: String
    ) async throws -> ByteBuffer {
        let sourceUrl = basePath.appendingPathComponent(source)
        let data = try Data(contentsOf: sourceUrl)
        return ByteBuffer.init(bytes: [UInt8](data))
    }

    func list(
        key: String?
    ) async throws -> [String] {
        let dirUrl = basePath.appendingPathComponent(key ?? "")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: dirUrl.path, isDirectory: &isDir), isDir.boolValue {
            let files = try FileManager.default.contentsOfDirectory(atPath: dirUrl.path)
            return files
        }
        /// it was a file... files don't have children, so we return an empty array.
        return []
    }
    
    func copy(
        key source: String,
        to destination: String
    ) async throws {
        let exists = await exists(key: source)
        guard exists else {
            throw ObjectStorageError.keyNotExists
        }
        try await delete(key: destination)
        let sourceUrl = basePath.appendingPathComponent(source)
        let destinationUrl = basePath.appendingPathComponent(destination)
        let location = destinationUrl.deletingLastPathComponent()
        try createDir(at: location)
        try FileManager.default.copyItem(at: sourceUrl, to: destinationUrl)
    }

    func move(
        key source: String,
        to destination: String
    ) async throws {
        try await copy(key: source, to: destination)
        try await delete(key: source)
    }

    func delete(
        key: String
    ) async throws {
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
    
    func createMultipartUpload(
        key: String
    ) async throws -> MultipartUpload.ID {
        .init("")
    }
    
    func uploadMultipartChunk(
        key: String,
        buffer: ByteBuffer,
        uploadId: MultipartUpload.ID,
        partNumber: Int
    ) async throws -> MultipartUpload.Chunk {
        .init(id: "", number: 0)
    }
    
    func cancelMultipartUpload(
        key: String,
        uploadId: MultipartUpload.ID
    ) async throws {
        
    }
    
    func completeMultipartUpload(
        key: String,
        uploadId: MultipartUpload.ID,
        checksum: String?,
        chunks: [LiquidKit.MultipartUpload.Chunk]
    ) async throws {
        
    }
}
