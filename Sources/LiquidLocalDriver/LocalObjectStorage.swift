//
//  LocalObjectStorage.swift
//  LiquidLocalDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import Foundation
import NIO
import NIOFoundationCompat
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
    
    func createChecksumCalculator() -> ChecksumCalculator {
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
        
        // TODO: needs better solution
        let calculator = createChecksumCalculator()
        if let data = buffer.getData(at: 0, length: buffer.readableBytes) {
            calculator.update(.init(data))
        }
        let dataChecksum = calculator.finalize()
        
        if let inputchecksum = checksum, inputchecksum != dataChecksum {
            throw ObjectStorageError.invalidChecksum
        }

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
        key: String,
        range: ClosedRange<UInt>?
    ) async throws -> ByteBuffer {
        let sourceUrl = basePath.appendingPathComponent(key)
        let data = try Data(contentsOf: sourceUrl)

        if let range, range.upperBound < data.count {
            return .init(
                data: data.subdata(
                    in: .init(
                        uncheckedBounds: (
                            Int(range.lowerBound),
                            Int(range.upperBound)
                        )
                    )
                )
            )
        }
        return .init(data: data)
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
        let uploadId = MultipartUpload.ID(UUID().uuidString)
        let multipartDirKey = key + "+multipart/" + uploadId.value
        try await create(key: multipartDirKey)
        return uploadId
    }
    
    func uploadMultipartChunk(
        key: String,
        buffer: ByteBuffer,
        uploadId: MultipartUpload.ID,
        partNumber: Int
    ) async throws -> MultipartUpload.Chunk {
        let multipartDirKey = key + "+multipart/" + uploadId.value
        let fileId = UUID().uuidString
        let fileKey = multipartDirKey + "/" + fileId + "-" + String(partNumber)
        try await upload(key: fileKey, buffer: buffer, checksum: nil)
        return .init(id: fileId, number: partNumber)
    }
    
    func cancelMultipartUpload(
        key: String,
        uploadId: MultipartUpload.ID
    ) async throws {
        let multipartBaseKey = key + "+multipart/"
        try await delete(key: multipartBaseKey)
    }
    
    func completeMultipartUpload(
        key: String,
        uploadId: MultipartUpload.ID,
        checksum: String?,
        chunks: [MultipartUpload.Chunk]
    ) async throws {
        let multipartBaseKey = key + "+multipart/"
        let multipartDirKey = multipartBaseKey + uploadId.value

        var data = Data()
        for chunk in chunks {
            let chunkKey = multipartDirKey + "/" + chunk.id + "-" + String(chunk.number)

            // TODO: needs better solution
            let buffer = try await download(key: chunkKey, range: nil)
            guard let chunkData = buffer.getData(at: 0, length: buffer.readableBytes) else {
                throw ObjectStorageError.keyNotExists
            }
            data.append(chunkData)
        }
        
        try await upload(
            key: key,
            buffer: .init(data: data),
            checksum: checksum
        )
        try await delete(key: multipartBaseKey)
    }
}
