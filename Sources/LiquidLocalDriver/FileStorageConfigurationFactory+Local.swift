//
//  File.swift
//  LiquidLocalStorageDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

public extension FileStorageConfigurationFactory {

    static func local(publicUrl: String,
                      publicPath: String,
                      workDirectory: String) -> FileStorageConfigurationFactory {
        .init { LiquidLocalStorageConfiguration(publicUrl: publicUrl,
                                                publicPath: publicPath,
                                                workDirectory: workDirectory) }
    }
}
