import Cocoa
import FlutterMacOS
import CoreAudio

class AudioDeviceChannel: NSObject, FlutterPlugin {
    static let channelName = "com.trusttune.audio_device"

    static func register(with registrar: FlutterPluginRegistrar) {
        print("[AudioDeviceChannel] register() called")
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger
        )
        let instance = AudioDeviceChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("[AudioDeviceChannel] Method channel registered with name: \(channelName)")
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("[AudioDeviceChannel] Received method call: \(call.method)")

        switch call.method {
        case "enumerateDevices":
            result(AudioDeviceChannel.enumerateAudioDevices())
        case "getDefaultDevice":
            result(AudioDeviceChannel.getDefaultOutputDevice())
        case "setAudioDevice":
            if let args = call.arguments as? [String: Any],
               let deviceId = args["deviceId"] as? String {
                AudioDeviceChannel.setOutputDevice(deviceId: deviceId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing deviceId", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    static func enumerateAudioDevices() -> [[String: Any]] {
        var devices: [[String: Any]] = []

        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get property data size: \(status)")
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get property data: \(status)")
            return devices
        }

        print("[AudioDeviceChannel] Found \(deviceCount) total audio devices")

        // Filter for output devices and get details
        for deviceId in audioDevices {
            if let deviceInfo = getDeviceInfo(deviceId: deviceId), deviceInfo["isOutput"] as? Bool == true {
                devices.append(deviceInfo)
                print("[AudioDeviceChannel] ✓ Output device: \(deviceInfo["name"] as? String ?? "Unknown")")
            }
        }

        return devices
    }

    static func getDeviceInfo(deviceId: AudioDeviceID) -> [String: Any]? {
        var deviceInfo: [String: Any] = [:]

        // Get device name
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get device name for ID \(deviceId): \(status)")
            return nil
        }

        // Get UID (unique identifier)
        propertyAddress.mSelector = kAudioDevicePropertyDeviceUID
        var deviceUID: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)
        status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceUID
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get device UID for ID \(deviceId): \(status)")
            return nil
        }

        // Check if device is output
        propertyAddress.mSelector = kAudioDevicePropertyStreams
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        dataSize = 0
        status = AudioObjectGetPropertyDataSize(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        let isOutput = (status == noErr && dataSize > 0)

        // Get transport type (USB, Bluetooth, Built-in, etc.)
        propertyAddress.mSelector = kAudioDevicePropertyTransportType
        propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
        var transportType: UInt32 = 0
        dataSize = UInt32(MemoryLayout<UInt32>.size)
        status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &transportType
        )

        let deviceType = getTransportTypeName(transportType: transportType)

        deviceInfo = [
            "id": deviceUID as String,
            "name": deviceName as String,
            "deviceId": String(deviceId),
            "isOutput": isOutput,
            "transportType": deviceType,
            "isBluetooth": (transportType == kAudioDeviceTransportTypeBluetooth),
            "isUSB": (transportType == kAudioDeviceTransportTypeUSB),
            "isBuiltIn": (transportType == kAudioDeviceTransportTypeBuiltIn),
            "isAirPlay": (transportType == kAudioDeviceTransportTypeAirPlay),
        ]

        // Log detailed info for Bluetooth devices
        if transportType == kAudioDeviceTransportTypeBluetooth {
            print("[AudioDeviceChannel] 🔵 Bluetooth device detected: \(deviceName)")
        }

        return deviceInfo
    }

    static func getTransportTypeName(transportType: UInt32) -> String {
        switch transportType {
        case kAudioDeviceTransportTypeBluetooth:
            return "bluetooth"
        case kAudioDeviceTransportTypeBuiltIn:
            return "builtin"
        case kAudioDeviceTransportTypeUSB:
            return "usb"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplay"
        case kAudioDeviceTransportTypeDisplayPort:
            return "displayport"
        case kAudioDeviceTransportTypeHDMI:
            return "hdmi"
        default:
            return "other"
        }
    }

    static func getDefaultOutputDevice() -> [String: Any]? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceId: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceId
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get default output device: \(status)")
            return nil
        }

        let deviceInfo = getDeviceInfo(deviceId: deviceId)
        if let info = deviceInfo {
            print("[AudioDeviceChannel] Default device: \(info["name"] as? String ?? "Unknown")")
        }

        return deviceInfo
    }

    static func setOutputDevice(deviceId: String, result: @escaping FlutterResult) {
        // Note: We don't actually change the system default device
        // Instead, we'll pass this to media_kit via the Dart layer
        // Just return success - the actual device switching happens in Dart
        print("[AudioDeviceChannel] Device selection request: \(deviceId)")
        result(["success": true, "deviceId": deviceId])
    }
}
