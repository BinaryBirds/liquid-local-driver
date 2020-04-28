import Foundation
import LiquidKit
import NIO

struct LiquidLocalStorageDriver: FileStorageDriver {
    let fileio: NonBlockingFileIO
    let configuration: LiquidLocalStorageConfiguration

    func makeStorage(with context: FileStorageContext) -> FileStorage {
        LiquidLocalStorage(fileio: self.fileio,
                           configuration: self.configuration,
                           context: context)
    }
    
    func shutdown() {

    }
}
