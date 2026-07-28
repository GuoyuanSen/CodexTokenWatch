import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift package-icns.swift ICONSET_DIR OUTPUT.icns\n", stderr)
    exit(64)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let representations: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianBytes(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}

var chunks = Data()
for representation in representations {
    let fileURL = iconsetURL.appendingPathComponent(representation.filename)
    let pngData = try Data(contentsOf: fileURL)
    let chunkLength = UInt32(8 + pngData.count)
    chunks.append(Data(representation.type.utf8))
    chunks.append(bigEndianBytes(chunkLength))
    chunks.append(pngData)
}

var icns = Data("icns".utf8)
icns.append(bigEndianBytes(UInt32(8 + chunks.count)))
icns.append(chunks)
try icns.write(to: outputURL, options: .atomic)
