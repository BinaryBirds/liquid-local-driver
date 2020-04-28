//
//  File.swift
//  
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import Foundation
import LiquidKit

struct LiquidLocalStorageConfiguration: FileStorageConfiguration {
    let publicUrl: String
    let publicPath: String
    let workDirectory: String

    func makeDriver(for storages: FileStorages) -> FileStorageDriver {
        return LiquidLocalStorageDriver(fileio: storages.fileio, configuration: self)
    }
}
