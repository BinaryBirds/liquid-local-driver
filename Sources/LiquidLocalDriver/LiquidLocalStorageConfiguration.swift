//
//  LiquidLocalStorageConfiguration.swift
//  LiquidLocalStorageDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

struct LiquidLocalStorageConfiguration: FileStorageConfiguration {
    let publicUrl: String
    let publicPath: String
    let workDirectory: String

    func makeDriver(for storages: FileStorages) -> FileStorageDriver {
        return LiquidLocalStorageDriver(fileio: storages.fileio, configuration: self)
    }
}
