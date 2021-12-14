import XCTest
@testable import LiquidLocalDriver

final class LiquidLocalDriverTests: XCTestCase {
    
    private func createTestStorage() throws -> FileStorage {
        
        let baseUrl = #file.split(separator: "/").dropLast().joined(separator: "/")

        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let pool = NIOThreadPool(numberOfThreads: 1)
        pool.start()

        let fileio = NonBlockingFileIO(threadPool: pool)

        let storages = FileStorages(fileio: fileio)
        storages.use(.local(publicUrl: "http://localhost/", publicPath: baseUrl, workDirectory: "assets"), as: .local)
        return storages.fileStorage(.local, logger: .init(label: "[test-logger]"), on: elg.next())!
    }
    
    func testUpload() async throws {
        let fs = try createTestStorage()
        let key = "test-01.txt"
        let data = Data("file storage test 01".utf8)
        let res = try await fs.upload(key: key, data: data)
        XCTAssertEqual(res, "http://localhost/assets/test-01.txt")
    }
    
    func testCreateDirectory() async throws {
        let fs = try createTestStorage()
        let key = "dir01/dir02/dir03"
        let _ = try await fs.createDirectory(key: key)
        let keys1 = try await fs.list(key: "dir01")
        XCTAssertEqual(keys1, ["dir02"])
        let keys2 = try await fs.list(key: "dir01/dir02")
        XCTAssertEqual(keys2, ["dir03"])
    }
    
    func testList() async throws {
        let fs = try createTestStorage()
        let key1 = "dir02/dir03"
        let _ = try await fs.createDirectory(key: key1)
        
        let key2 = "dir02/test-01.txt"
        let data = Data("test".utf8)
        _ = try await fs.upload(key: key2, data: data)
        
        let res = try await fs.list(key: "dir02")
        XCTAssertEqual(res, ["dir03", "test-01.txt"])
    }
    
    func testExists() async throws {
        let fs = try createTestStorage()

        let key1 = "non-existing-thing"
        let exists1 = await fs.exists(key: key1)
        XCTAssertFalse(exists1)
        
        let key2 = "my/dir"
        _ = try await fs.createDirectory(key: key2)
        let exists2 = await fs.exists(key: key2)
        XCTAssertTrue(exists2)
    }
    
    func testGetFile() async throws {
        let fs = try createTestStorage()

        let key2 = "dir04/test-01.txt"
        let data = Data("test".utf8)
        let url = try await fs.upload(key: key2, data: data)
        print(url)
        
        guard let res = try await fs.getObject(key: key2) else {
            return XCTFail()
        }
        XCTAssertEqual(String(data: res, encoding: .utf8), "test")
    }
    
    func testListFile() async throws {
        let fs = try createTestStorage()

        let key2 = "dir04/test-01.txt"
        let data = Data("test".utf8)
        _ = try await fs.upload(key: key2, data: data)
        
        let res = try await fs.list(key: key2)
        XCTAssertEqual(res, [])
    }
    
    func testCopy() async throws {
        let fs = try createTestStorage()
        let key = "test-02.txt"
        let data = Data("file storage test 02".utf8)
        let res = try await fs.upload(key: key, data: data)
        XCTAssertEqual(res, "http://localhost/assets/test-02.txt")
        
        let dest = "test-03.txt"
        let res2 = try await fs.copy(key: key, to: dest)
        
        XCTAssertEqual(res2, "http://localhost/assets/test-03.txt")
        
        let res3 = await fs.exists(key: key)
        XCTAssertTrue(res3)
        let res4 = await fs.exists(key: dest)
        XCTAssertTrue(res4)
    }
    
    func testMove() async throws {
        let fs = try createTestStorage()
        let key = "test-04.txt"
        let data = Data("file storage test 04".utf8)
        let res = try await fs.upload(key: key, data: data)
        XCTAssertEqual(res, "http://localhost/assets/test-04.txt")
        
        let dest = "test-05.txt"
        let res2 = try await fs.move(key: key, to: dest)
        
        XCTAssertEqual(res2, "http://localhost/assets/test-05.txt")
        
        let res3 = await fs.exists(key: key)
        XCTAssertFalse(res3)
        let res4 = await fs.exists(key: dest)
        XCTAssertTrue(res4)
    }
    
}
