// swift-tools-version: 5.7
import PackageDescription
let package = Package(name:"KshonGCS",platforms:[.macOS(.v12)],products:[.executable(name:"KshonGCS",targets:["KshonGCS"])],targets:[.executableTarget(name:"KshonGCS",path:"Sources/KshonGCS")])
