//
//  LocalFileStorageDriverFactory.swift
//  LiquidLocalDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import NIO
import LiquidKit

struct LocalFileStorageDriverFactory: FileStorageDriverFactory {
    
    let fileio: NonBlockingFileIO
    let byteBufferAllocator: ByteBufferAllocator

    func makeDriver(
        using context: FileStorageDriverContext
    ) -> FileStorageDriver {
         LocalFileStorageDriver(
            fileio: fileio,
            byteBufferAllocator: byteBufferAllocator,
            context: context
         )
    }
    
    func shutdown() {
        // do nothing...
    }
}
