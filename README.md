# LiquidLocalDriver

A local driver implementation for the [LiquidKit](https://github.com/BinaryBirds/liquid-kit) file storage solution.

The local driver uses a local directory on the server and the FileManager object from the Foundation framework to store files. If you are planning to setup a distributed system with multiple application servers, please consider using the [AWS S3](https://github.com/BinaryBirds/liquid-aws-s3-driver) driver instead. 

LiquidKit and the local driver is also compatible with Vapor 4 through the [Liquid](https://github.com/BinaryBirds/liquid) repository, that contains Vapor specific extensions.


## Key resolution for local objects

Keys are being resolved using a public base URL component, the name of the working directory and the key itself.

- url = [public base URL] + [working directory name] + [key]

e.g. 

- publicUrl = "http://localhost/"
- workDirectory = "assets"
- key = "test.txt"

- resolvedUrl = "http://localhost/assets/test.txt"


## Usage with SwiftNIO

Add the required dependencies using SPM:

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "myProject",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/binarybirds/liquid", from: "1.3.0"),
        .package(url: "https://github.com/binarybirds/liquid-local-driver", from: "1.3.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Liquid", package: "liquid"),
            .product(name: "LiquidLocalDriver", package: "liquid-local-driver"),
        ]),
    ]
)
```

A basic usage example with SwiftNIO:

```swift
/// setup thread pool
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let pool = NIOThreadPool(numberOfThreads: 1)
pool.start()

/// create fs  
let fileio = NonBlockingFileIO(threadPool: pool)
let storages = FileStorages(fileio: fileio)
storages.use(.local(publicUrl: "http://localhost/",
                    publicPath: "/var/www/localhost/public",
                    workDirectory: "assets"), as: .local)
let fs = storages.fileStorage(.local, logger: .init(label: "[test-logger]"), on: elg.next())!

/// test file upload
let key = "test.txt"
let data = Data("file storage test".utf8)
let res = try await fs.upload(key: key, data: data)

/// http://localhost/assets/test.txt
let url = req.fs.resolve(key: key)

/// delete key
try await req.fs.delete(key: key)

```

