//
//  LiquidLocalDriverTests+Basics.swift
//  LiquidLocalDriverTests
//
//  Created by Tibor Bodecs on 2023. 02. 07..
//

import XCTest
import NIO
import NIOFoundationCompat
import Logging
import LiquidKit
@testable import LiquidLocalDriver

final class LiquidLocalDriverTests_Basics: LiquidLocalDriverTestCase {

    func testUpload() async throws {

        let key = "test-01.txt"
        let data = Data("file storage test 01".utf8)
        try await os.upload(
            key: key,
            buffer: .init(bytes: [UInt8](data)),
            checksum: nil
        )
    }
    
    func testUploadValidChecksum() async throws {
        let key = "test-01.txt"
        let data = Data("file storage test 01".utf8)
        
        let calculator = os.createChecksumCalculator()
        calculator.update(.init(data))
        let checksum = calculator.finalize()
        
        try await os.upload(
            key: key,
            buffer: .init(bytes: [UInt8](data)),
            checksum: checksum
        )
    }
    
    func testUploadInvalidChecksum() async throws {
        
        let key = "test-01.txt"
        let data = Data("file storage test 01".utf8)
        
        do {
            try await os.upload(
                key: key,
                buffer: .init(bytes: [UInt8](data)),
                checksum: "invalid"
            )
            XCTFail("Upload should not be allowed with invalid checksums.")
        }
        catch ObjectStorageError.invalidChecksum {
            // we're ok
        }
    }

    func testCreate() async throws {
        let key = "dir01/dir02/dir03"
        try await os.create(key: key)
        
        let keys1 = try await os.list(key: "dir01")
        XCTAssertEqual(keys1, ["dir02"])
        
        let keys2 = try await os.list(key: "dir01/dir02")
        XCTAssertEqual(keys2, ["dir03"])
    }

    func testList() async throws {
        let key1 = "dir02/dir03"
        try await os.create(key: key1)

        let key2 = "dir02/test-01.txt"
        let data = Data("test".utf8)
        try await os.upload(
            key: key2,
            buffer: .init(data: data),
            checksum: nil
        )

        let res = try await os.list(key: "dir02")
        XCTAssertEqual(res, ["dir03", "test-01.txt"])
    }

    func testExists() async throws {
        let key1 = "non-existing-thing"
        let exists1 = await os.exists(key: key1)
        XCTAssertFalse(exists1)

        let key2 = "my/dir"
        try await os.create(key: key2)
        let exists2 = await os.exists(key: key2)
        XCTAssertTrue(exists2)
    }

    func testDownload() async throws {
        let key2 = "dir04/test-01.txt"
        let data = Data("test".utf8)
        try await os.upload(
            key: key2,
            buffer: .init(data: data),
            checksum: nil
        )

        let res = try await os.download(key: key2, range: nil)
        guard let resData = res.getData(at: 0, length: res.readableBytes) else {
            return XCTFail("Byte buffer should contain valid data.")
        }
        XCTAssertEqual(String(data: resData, encoding: .utf8), "test")
    }
    
    func testDownloadRange() async throws {
        let key2 = "dir04/test-01.txt"
        let data = Data("test".utf8)
        try await os.upload(
            key: key2,
            buffer: .init(data: data),
            checksum: nil
        )

        let res = try await os.download(key: key2, range: 1...3)
        guard
            let resData = res.getData(at: 0, length: res.readableBytes),
            let res = String(data: resData, encoding: .utf8)
        else {
            return XCTFail("Byte buffer should contain valid data.")
        }
        XCTAssertEqual(res, "es")
    }

    func testListFile() async throws {
        let key2 = "dir04/test-01.txt"
        let data = Data("test".utf8)
        try await os.upload(
            key: key2,
            buffer: .init(data: data),
            checksum: nil
        )

        let res = try await os.list(key: key2)
        XCTAssertEqual(res, [])
    }

    func testCopy() async throws {
        let key = "test-02.txt"
        let data = Data("file storage test 02".utf8)
        try await os.upload(
            key: key,
            buffer: .init(data: data),
            checksum: nil
        )
        
        let dest = "test-03.txt"
        try await os.copy(key: key, to: dest)

        let res3 = await os.exists(key: key)
        XCTAssertTrue(res3)

        let res4 = await os.exists(key: dest)
        XCTAssertTrue(res4)
    }

    func testMove() async throws {
        let key = "test-04.txt"
        let data = Data("file storage test 04".utf8)
        try await os.upload(
            key: key,
            buffer: .init(data: data),
            checksum: nil
        )

        let dest = "test-05.txt"
        try await os.move(key: key, to: dest)

        let res3 = await os.exists(key: key)
        XCTAssertFalse(res3)

        let res4 = await os.exists(key: dest)
        XCTAssertTrue(res4)
    }
    
    func testMultipartUploadCreate() async throws {
        let key = "test-04.txt"
        let id = try await os.createMultipartUpload(key: key)

        let res = await os.exists(key: key + "+multipart/" + id.value)
        XCTAssertTrue(res)
    }
    
    func testMultipartUploadCancel() async throws {

        let key = "test-04.txt"
        let id = try await os.createMultipartUpload(key: key)
        
        try await os.cancelMultipartUpload(key: key, uploadId: id)

        let res = await os.exists(key: key + "+multipart/" + id.value)
        XCTAssertFalse(res)
    }

    func testMultipartUploadChunk() async throws {
        let key = "test-04.txt"
        let data = Data("file storage test 04".utf8)
        
        let id = try await os.createMultipartUpload(key: key)
        
        let chunk = try await os.uploadMultipartChunk(
            key: key,
            buffer: .init(data: data),
            uploadId: id,
            partNumber: 1
        )
        
        let res = await os.exists(
            key: key + "+multipart/" + id.value + "/" + chunk.id + "-" + String(chunk.number)
        )
        XCTAssertTrue(res)
    }
    
    func testMultipartUploadComplete() async throws {

        let key = "test-04.txt"

        let id = try await os.createMultipartUpload(key: key)
        
        let data1 = Data("lorem ipsum".utf8)
        let chunk1 = try await os.uploadMultipartChunk(
            key: key,
            buffer: .init(data: data1),
            uploadId: id,
            partNumber: 1
        )
        
        let data2 = Data(" dolor sit amet".utf8)
        let chunk2 = try await os.uploadMultipartChunk(
            key: key,
            buffer: .init(data: data2),
            uploadId: id,
            partNumber: 2
        )
        
        try await os.completeMultipartUpload(
            key: key,
            uploadId: id,
            checksum: nil,
            chunks: [
                chunk1,
                chunk2,
            ]
        )
        
        let file = try await os.download(key: key, range: nil)
        
        guard
            let data = file.getData(at: 0, length: file.readableBytes),
            let value = String(data: data, encoding: .utf8)
        else {
            return XCTFail("Missing or invalid file data.")
        }
        
        XCTAssertEqual(value, "lorem ipsum dolor sit amet")
    }
}