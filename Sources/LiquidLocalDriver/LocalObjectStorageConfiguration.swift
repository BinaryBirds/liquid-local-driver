//
//  LocalObjectStorageConfiguration.swift
//  LiquidLocalDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import NIO
import LiquidKit

struct LocalObjectStorageConfiguration: ObjectStorageConfiguration {

    /// The public base URL used to resolve file keys (e.g. http://localhost/)
    let publicUrl: String
    
    /// The path of the public asset storage on the server (e.g. /var/www/localhost/public/)
    let publicPath: String
    
    /// The working directory name used to save assets (e.g. assets)
    let workDirectory: String
    
    let posixMode: mode_t

    func make(
        using storages: ObjectStorages
    ) -> ObjectStorageDriver {
        LocalObjectStorageDriver(
            fileio: storages.fileio,
            byteBufferAllocator: storages.byteBufferAllocator
        )
    }
}
