import Darwin
import Foundation

enum UsbMuxClient {
    struct Device: Hashable {
        let deviceID: Int
        let name: String
        let serialNumber: String
    }

    enum UsbMuxError: Error, LocalizedError {
        case socketOpenFailed
        case connectFailed(String)
        case invalidResponse
        case noSuchDevice
        case devicePortUnavailable(Int)
        case shortRead
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .socketOpenFailed:
                return "usbmuxd 소켓을 열 수 없습니다"
            case .connectFailed(let path):
                return "usbmuxd 연결 실패: \(path)"
            case .invalidResponse:
                return "usbmuxd 응답이 올바르지 않습니다"
            case .noSuchDevice:
                return "USB iPad를 찾을 수 없습니다"
            case .devicePortUnavailable(let port):
                return "USB iPad의 포트 \(port)에 연결할 수 없습니다. iPad에서 화면 방송을 먼저 시작하세요."
            case .shortRead:
                return "USB 연결에서 데이터를 끝까지 읽지 못했습니다"
            case .writeFailed:
                return "USB 연결에 데이터를 쓰지 못했습니다"
            }
        }
    }

    private static let socketPath = "/var/run/usbmuxd"
    private static let protocolVersion: UInt32 = 1
    private static let plistMessageType: UInt32 = 8
    private static let maximumPlistResponseSize = 4 * 1024 * 1024

    static func listDevices() throws -> [Device] {
        let socket = try openMuxSocket()
        defer { close(socket) }

        let response = try sendMuxPlist(
            [
                "MessageType": "ListDevices",
                "ClientVersionString": "iPadMirrorMac",
                "ProgName": "iPadMirrorMac",
                "kLibUSBMuxVersion": 3
            ],
            socket: socket,
            tag: 1
        )

        guard let deviceList = response["DeviceList"] as? [[String: Any]] else {
            return []
        }

        return deviceList.compactMap { entry in
            guard let deviceID = entry["DeviceID"] as? Int,
                  let properties = entry["Properties"] as? [String: Any] else {
                return nil
            }

            let serial = (properties["SerialNumber"] as? String)
                ?? (properties["USBSerialNumber"] as? String)
                ?? "unknown"
            let fallbackName = "USB iPad \(serial.suffix(4))"
            let name = (try? deviceName(deviceID: deviceID)) ?? fallbackName
            return Device(deviceID: deviceID, name: name, serialNumber: serial)
        }
    }

    static func connectToDevice(deviceID: Int, port: UInt16) throws -> Int32 {
        let socket = try openMuxSocket()

        do {
            let response = try sendMuxPlist(
                [
                    "MessageType": "Connect",
                    "ClientVersionString": "iPadMirrorMac",
                    "ProgName": "iPadMirrorMac",
                    "DeviceID": deviceID,
                    "PortNumber": Int(port.bigEndian)
                ],
                socket: socket,
                tag: 2
            )

            guard let number = response["Number"] as? Int else {
                close(socket)
                throw UsbMuxError.invalidResponse
            }

            guard number == 0 else {
                close(socket)
                throw UsbMuxError.devicePortUnavailable(Int(port))
            }

            return socket
        } catch {
            close(socket)
            throw error
        }
    }

    static func readExact(from socket: Int32, byteCount: Int) throws -> Data {
        var data = Data(count: byteCount)
        var offset = 0

        try data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }

            while offset < byteCount {
                let count = Darwin.read(socket, baseAddress.advanced(by: offset), byteCount - offset)
                if count == 0 {
                    throw UsbMuxError.shortRead
                }
                if count < 0 {
                    if errno == EINTR { continue }
                    throw UsbMuxError.shortRead
                }
                offset += count
            }
        }

        return data
    }

    static func writeAll(_ data: Data, to socket: Int32) throws {
        var offset = 0

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }

            while offset < data.count {
                let count = Darwin.write(socket, baseAddress.advanced(by: offset), data.count - offset)
                if count == 0 {
                    throw UsbMuxError.writeFailed
                }
                if count < 0 {
                    if errno == EINTR { continue }
                    throw UsbMuxError.writeFailed
                }
                offset += count
            }
        }
    }

    private static func deviceName(deviceID: Int) throws -> String {
        let socket = try connectToDevice(deviceID: deviceID, port: 62_078)
        defer { close(socket) }

        _ = try sendLockdownPlist(["Request": "QueryType"], socket: socket)
        let response = try sendLockdownPlist(["Request": "GetValue", "Key": "DeviceName"], socket: socket)

        guard let name = response["Value"] as? String, !name.isEmpty else {
            throw UsbMuxError.invalidResponse
        }
        return name
    }

    private static func openMuxSocket() throws -> Int32 {
        let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else { throw UsbMuxError.socketOpenFailed }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(socketPath.utf8CString)
        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= maxPathLength else {
            close(socketFD)
            throw UsbMuxError.connectFailed(socketPath)
        }

        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            _ = buffer.initializeMemory(as: CChar.self, from: pathBytes)
        }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            close(socketFD)
            throw UsbMuxError.connectFailed(socketPath)
        }

        return socketFD
    }

    private static func sendMuxPlist(_ plist: [String: Any], socket: Int32, tag: UInt32) throws -> [String: Any] {
        let payload = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        var packet = Data()
        appendLittleEndian(UInt32(16 + payload.count), to: &packet)
        appendLittleEndian(protocolVersion, to: &packet)
        appendLittleEndian(plistMessageType, to: &packet)
        appendLittleEndian(tag, to: &packet)
        packet.append(payload)

        try writeAll(packet, to: socket)

        let header = try readExact(from: socket, byteCount: 16)
        let responseLength = Int(readUInt32LittleEndian(header, offset: 0))
        guard responseLength >= 16, responseLength <= maximumPlistResponseSize else {
            throw UsbMuxError.invalidResponse
        }

        let responsePayload = try readExact(from: socket, byteCount: responseLength - 16)
        guard let response = try PropertyListSerialization.propertyList(from: responsePayload, options: [], format: nil) as? [String: Any] else {
            throw UsbMuxError.invalidResponse
        }
        return response
    }

    private static func sendLockdownPlist(_ plist: [String: Any], socket: Int32) throws -> [String: Any] {
        let payload = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        var packet = Data()
        appendBigEndian(UInt32(payload.count), to: &packet)
        packet.append(payload)

        try writeAll(packet, to: socket)

        let header = try readExact(from: socket, byteCount: 4)
        let responseLength = Int(readUInt32BigEndian(header, offset: 0))
        guard responseLength > 0, responseLength <= maximumPlistResponseSize else {
            throw UsbMuxError.invalidResponse
        }
        let responsePayload = try readExact(from: socket, byteCount: responseLength)

        guard let response = try PropertyListSerialization.propertyList(from: responsePayload, options: [], format: nil) as? [String: Any] else {
            throw UsbMuxError.invalidResponse
        }
        return response
    }

    private static func appendLittleEndian(_ value: UInt32, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        data.append(Data(bytes: &littleEndianValue, count: MemoryLayout<UInt32>.size))
    }

    private static func appendBigEndian(_ value: UInt32, to data: inout Data) {
        var bigEndianValue = value.bigEndian
        data.append(Data(bytes: &bigEndianValue, count: MemoryLayout<UInt32>.size))
    }

    private static func readUInt32LittleEndian(_ data: Data, offset: Int) -> UInt32 {
        guard data.count >= offset + 4 else { return 0 }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func readUInt32BigEndian(_ data: Data, offset: Int) -> UInt32 {
        guard data.count >= offset + 4 else { return 0 }
        return (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }
}
