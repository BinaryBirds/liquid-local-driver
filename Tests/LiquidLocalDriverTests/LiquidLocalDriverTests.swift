import XCTest
import NIO
import NIOFoundationCompat
import Logging
import LiquidKit
@testable import LiquidLocalDriver

final class LiquidLocalDriverTests: XCTestCase {

    private static let workDir = "tmp"
    
    private static func getBasePath() -> String {
        "/" + #file
            .split(separator: "/")
            .dropLast()
            .joined(separator: "/")
    }
    
    private func createTestDriver() -> LocalObjectStorage {
        let logger = Logger(label: "test-logger")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let pool = NIOThreadPool(numberOfThreads: 1)
        let fileio = NonBlockingFileIO(threadPool: pool)
        pool.start()

        let objectStorages = ObjectStorages(
            eventLoopGroup: eventLoopGroup,
            byteBufferAllocator: .init(),
            fileio: fileio
        )

        objectStorages.use(
            .local(
                publicUrl: "http://localhost/",
                publicPath: Self.getBasePath(),
                workDirectory: Self.workDir
            ),
            as: .local
        )

        return objectStorages.make(
            logger: logger,
            on: eventLoopGroup.next()
        )! as! LocalObjectStorage
    }


    // NOTE: unique dir for each test, this won't work for parallel test runs
    override class func tearDown() {
//        let path = getBasePath() + "/" + workDir
//        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - tests

    func testUpload() async throws {
        let fs = createTestDriver()
        let key = "test-01.txt"
        let data = Data("file storage test 01".utf8)
        try await fs.upload(
            key: key,
            buffer: .init(bytes: [UInt8](data)),
            checksum: nil
        )
    }
    
    func testUploadValidChecksum() async throws {
        let fs = createTestDriver()
        let key = "test-01.txt"
        let data = Data("file storage test 01".utf8)
        
        let calculator = fs.createChecksumCalculator()
        calculator.update(.init(data))
        let checksum = calculator.finalize()
        
        try await fs.upload(
            key: key,
            buffer: .init(bytes: [UInt8](data)),
            checksum: checksum
        )
    }
    
    func testUploadInvalidChecksum() async throws {
        let fs = createTestDriver()
        let key = "test-01.txt"
        let data = Data("file storage test 01".utf8)
        
        do {
            try await fs.upload(
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
        let fs = createTestDriver()
        
        let key = "dir01/dir02/dir03"
        try await fs.create(key: key)
        
        let keys1 = try await fs.list(key: "dir01")
        XCTAssertEqual(keys1, ["dir02"])
        
        let keys2 = try await fs.list(key: "dir01/dir02")
        XCTAssertEqual(keys2, ["dir03"])
    }

    func testList() async throws {
        let fs = createTestDriver()
        let key1 = "dir02/dir03"
        try await fs.create(key: key1)

        let key2 = "dir02/test-01.txt"
        let data = Data("test".utf8)
        try await fs.upload(
            key: key2,
            buffer: .init(data: data),
            checksum: nil
        )

        let res = try await fs.list(key: "dir02")
        XCTAssertEqual(res, ["dir03", "test-01.txt"])
    }

    func testExists() async throws {
        let fs = createTestDriver()

        let key1 = "non-existing-thing"
        let exists1 = await fs.exists(key: key1)
        XCTAssertFalse(exists1)

        let key2 = "my/dir"
        try await fs.create(key: key2)
        let exists2 = await fs.exists(key: key2)
        XCTAssertTrue(exists2)
    }

    func testDownload() async throws {
        let fs = createTestDriver()

        let key2 = "dir04/test-01.txt"
        let data = Data("test".utf8)
        try await fs.upload(
            key: key2,
            buffer: .init(data: data),
            checksum: nil
        )

        let res = try await fs.download(key: key2)
        guard let resData = res.getData(at: 0, length: res.readableBytes) else {
            return XCTFail("Byte buffer should contain valid data.")
        }
        XCTAssertEqual(String(data: resData, encoding: .utf8), "test")
    }

    func testListFile() async throws {
        let fs = createTestDriver()

        let key2 = "dir04/test-01.txt"
        let data = Data("test".utf8)
        try await fs.upload(
            key: key2,
            buffer: .init(data: data),
            checksum: nil
        )

        let res = try await fs.list(key: key2)
        XCTAssertEqual(res, [])
    }

    func testCopy() async throws {
        let fs = createTestDriver()
        let key = "test-02.txt"
        let data = Data("file storage test 02".utf8)
        try await fs.upload(
            key: key,
            buffer: .init(data: data),
            checksum: nil
        )
        
        let dest = "test-03.txt"
        try await fs.copy(key: key, to: dest)

        let res3 = await fs.exists(key: key)
        XCTAssertTrue(res3)

        let res4 = await fs.exists(key: dest)
        XCTAssertTrue(res4)
    }

    func testMove() async throws {
        let fs = createTestDriver()
        let key = "test-04.txt"
        let data = Data("file storage test 04".utf8)
        try await fs.upload(
            key: key,
            buffer: .init(data: data),
            checksum: nil
        )

        let dest = "test-05.txt"
        try await fs.move(key: key, to: dest)

        let res3 = await fs.exists(key: key)
        XCTAssertFalse(res3)

        let res4 = await fs.exists(key: dest)
        XCTAssertTrue(res4)
    }
    
    func testMultipartUploadCreate() async throws {
        let fs = createTestDriver()

        let key = "test-04.txt"
        let id = try await fs.createMultipartUpload(key: key)

        let res = await fs.exists(key: key + "+multipart/" + id.value)
        XCTAssertTrue(res)
    }
    
    func testMultipartUploadCancel() async throws {
        let fs = createTestDriver()

        let key = "test-04.txt"
        let id = try await fs.createMultipartUpload(key: key)
        
        try await fs.cancelMultipartUpload(key: key, uploadId: id)

        let res = await fs.exists(key: key + "+multipart/" + id.value)
        XCTAssertFalse(res)
    }

    func testMultipartUploadChunk() async throws {
        let fs = createTestDriver()

        let key = "test-04.txt"
        let data = Data("file storage test 04".utf8)
        
        let id = try await fs.createMultipartUpload(key: key)
        
        let chunk = try await fs.uploadMultipartChunk(
            key: key,
            buffer: .init(data: data),
            uploadId: id,
            partNumber: 1
        )
        
        let res = await fs.exists(
            key: key + "+multipart/" + id.value + "/" + chunk.id + "-" + String(chunk.number)
        )
        XCTAssertTrue(res)
    }
    
    func testMultipartUploadComplete() async throws {
        let fs = createTestDriver()

        let key = "test-04.txt"

        let id = try await fs.createMultipartUpload(key: key)
        
        let data1 = Data("lorem ipsum".utf8)
        let chunk1 = try await fs.uploadMultipartChunk(
            key: key,
            buffer: .init(data: data1),
            uploadId: id,
            partNumber: 1
        )
        
        let data2 = Data(" dolor sit amet".utf8)
        let chunk2 = try await fs.uploadMultipartChunk(
            key: key,
            buffer: .init(data: data2),
            uploadId: id,
            partNumber: 2
        )
        
        try await fs.completeMultipartUpload(
            key: key,
            uploadId: id,
            checksum: nil,
            chunks: [
                chunk1,
                chunk2,
            ]
        )
        
        let file = try await fs.download(key: key)
        
        guard
            let data = file.getData(at: 0, length: file.readableBytes),
            let value = String(data: data, encoding: .utf8)
        else {
            return XCTFail("Missing or invalid file data.")
        }
        
        XCTAssertEqual(value, "lorem ipsum dolor sit amet")
    }
}
