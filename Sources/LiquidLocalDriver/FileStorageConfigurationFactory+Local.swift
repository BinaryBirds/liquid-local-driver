//
//  File.swift
//  LiquidLocalStorageDriver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

public extension FileStorageConfigurationFactory {

    ///
    /// Creates a local configuration object based on the parameters
    ///
    /// - parameters:
    ///     - publicUrl: The public base URL used to resolve file keys (e.g. http://localhost/)
    ///     - publicPath: The path of the public asset storage on the server (e.g. /var/www/localhost/public/)
    ///     - workDirectory: The working directory name used to save assets (e.g. assets)
    static func local(publicUrl: String, publicPath: String, workDirectory: String) -> FileStorageConfigurationFactory {
        .init { LiquidLocalStorageConfiguration(publicUrl: publicUrl, publicPath: publicPath, workDirectory: workDirectory) }
    }
}
