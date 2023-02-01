//
//  LocalObjectStorageDriver.swift
//  LiquidLocalDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import NIO
import LiquidKit

struct LocalObjectStorageDriver: ObjectStorageDriver {
    
    let fileio: NonBlockingFileIO
    let byteBufferAllocator: ByteBufferAllocator

    func make(
        using context: ObjectStorageContext
    ) -> ObjectStorage {
         LocalObjectStorage(
            fileio: fileio,
            byteBufferAllocator: byteBufferAllocator,
            context: context
         )
    }
    
    func shutdown() {
        // nothing to do...
    }
}
