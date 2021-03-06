//
//  LiquidLocalStorageConfiguration.swift
//  LiquidLocalStorageDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

struct LiquidLocalStorageConfiguration: FileStorageConfiguration {
    
    /// The public base URL used to resolve file keys (e.g. http://localhost/)
    let publicUrl: String
    
    /// The path of the public asset storage on the server (e.g. /var/www/localhost/public/)
    let publicPath: String
    
    /// The working directory name used to save assets (e.g. assets)
    let workDirectory: String

    func makeDriver(for storages: FileStorages) -> FileStorageDriver {
        LiquidLocalStorageDriver(fileio: storages.fileio, configuration: self)
    }
}
