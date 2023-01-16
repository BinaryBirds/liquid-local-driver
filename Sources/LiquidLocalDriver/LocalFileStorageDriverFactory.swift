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

    func makeDriver(
        using context: FileStorageDriverContext
    ) -> FileStorageDriver {
         LocalFileStorageDriver(fileio: fileio, context: context)
    }
    
    func shutdown() {
        // do nothing...
    }
}
