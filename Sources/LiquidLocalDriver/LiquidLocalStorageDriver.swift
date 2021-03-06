//
//  LiquidLocalStorageDriver.swift
//  LiquidLocalStorageDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

struct LiquidLocalStorageDriver: FileStorageDriver {

    let fileio: NonBlockingFileIO
    let configuration: LiquidLocalStorageConfiguration

    func makeStorage(with context: FileStorageContext) -> FileStorage {
        LiquidLocalStorage(fileio: fileio, configuration: configuration, context: context)
    }
    
    func shutdown() {}
}
