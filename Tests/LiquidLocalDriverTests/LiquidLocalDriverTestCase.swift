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

extension ByteBuffer {

    var utf8String: String? {
        guard
            let data = getData(at: 0, length: readableBytes),
            let res = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return res
    }
}

open class LiquidLocalDriverTestCase: XCTestCase {

    func getBasePath() -> String {
        "/" + #file
            .split(separator: "/")
            .dropLast()
            .joined(separator: "/")
    }
    
    func getAssetsPath() -> String {
        return getBasePath() + "/Assets/"
    }
    
    private func createTestObjectStorages(
        logger: Logger
    ) -> ObjectStorages {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let pool = NIOThreadPool(numberOfThreads: 1)
        let fileio = NonBlockingFileIO(threadPool: pool)
        pool.start()

        return .init(
            eventLoopGroup: eventLoopGroup,
            byteBufferAllocator: .init(),
            fileio: fileio
        )
    }

    private func createTestStorage(
        using storages: ObjectStorages,
        logger: Logger
    ) -> LocalObjectStorage {

        storages.use(
            .local(
                publicUrl: "http://localhost/",
                publicPath: workPath,
                workDirectory: workDir
            ),
            as: .local
        )

        return storages.make(
            logger: logger,
            on: storages.eventLoopGroup.next()
        )! as! LocalObjectStorage
    }
    
    var workPath: String!
    var workDir: String!
    var storages: ObjectStorages!
    var os: LocalObjectStorage!

    open override func setUp() {
        workPath = getBasePath() + "/tmp/"
        workDir = UUID().uuidString
        
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: workPath + workDir),
            withIntermediateDirectories: true
        )

        let logger = Logger(label: "test-logger")
        storages = createTestObjectStorages(logger: logger)
        os = createTestStorage(using: storages, logger: logger)
        
        super.setUp()
    }

    open override func tearDown() {
        try? FileManager.default.removeItem(atPath: workPath + workDir)

        storages.shutdown()
        
        super.tearDown()
    }
}
