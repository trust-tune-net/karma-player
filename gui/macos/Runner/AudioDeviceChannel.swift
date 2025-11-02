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
        case "supportsExclusiveMode":
            if let args = call.arguments as? [String: Any],
               let deviceUID = args["deviceId"] as? String {
                result(AudioDeviceChannel.supportsExclusiveMode(deviceUID: deviceUID))
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing deviceId", details: nil))
            }
        case "enableExclusiveMode":
            if let args = call.arguments as? [String: Any],
               let deviceUID = args["deviceId"] as? String,
               let enable = args["enable"] as? Bool {
                AudioDeviceChannel.setExclusiveMode(deviceUID: deviceUID, enable: enable, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing deviceId or enable", details: nil))
            }
        case "getDeviceFormat":
            if let args = call.arguments as? [String: Any],
               let deviceUID = args["deviceId"] as? String {
                result(AudioDeviceChannel.getDeviceFormat(deviceUID: deviceUID))
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing deviceId", details: nil))
            }
        case "getDeviceMetadata":
            if let args = call.arguments as? [String: Any],
               let deviceUID = args["deviceId"] as? String {
                result(AudioDeviceChannel.getDeviceMetadata(deviceUID: deviceUID))
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

    // MARK: - Exclusive Mode (Integer Mode) Support

    /// Check if a device supports exclusive mode (Integer Mode on macOS)
    static func supportsExclusiveMode(deviceUID: String) -> [String: Any] {
        guard let deviceId = getDeviceIdFromUID(deviceUID: deviceUID) else {
            return ["supported": false, "reason": "Device not found"]
        }

        // All CoreAudio devices support Hog Mode, but some may not support Integer Mode
        // For now, we'll return true for all devices and handle errors at runtime
        print("[AudioDeviceChannel] Device \(deviceUID) supports exclusive mode")
        return [
            "supported": true,
            "mode": "integer", // macOS uses Integer Mode
            "deviceId": String(deviceId)
        ]
    }

    /// Enable or disable exclusive mode (Hog Mode) for a device
    static func setExclusiveMode(deviceUID: String, enable: Bool, result: @escaping FlutterResult) {
        guard let deviceId = getDeviceIdFromUID(deviceUID: deviceUID) else {
            result(FlutterError(
                code: "DEVICE_NOT_FOUND",
                message: "Audio device with UID \(deviceUID) not found",
                details: nil
            ))
            return
        }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyHogMode,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if property is settable
        var isSettable: DarwinBoolean = false
        var status = AudioObjectIsPropertySettable(deviceId, &propertyAddress, &isSettable)

        guard status == noErr, isSettable.boolValue else {
            result(FlutterError(
                code: "NOT_SETTABLE",
                message: "Device does not support exclusive mode (Hog Mode)",
                details: ["deviceId": deviceUID]
            ))
            return
        }

        // Set Hog Mode
        var hogPid: pid_t = enable ? getpid() : -1
        var dataSize = UInt32(MemoryLayout<pid_t>.size)

        status = AudioObjectSetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            dataSize,
            &hogPid
        )

        if status == noErr {
            // Verify by reading back the Hog Mode value
            var verifyHogPid: pid_t = -1
            var verifyDataSize = UInt32(MemoryLayout<pid_t>.size)
            let verifyStatus = AudioObjectGetPropertyData(
                deviceId,
                &propertyAddress,
                0,
                nil,
                &verifyDataSize,
                &verifyHogPid
            )

            let actuallyEnabled = (verifyStatus == noErr && verifyHogPid == getpid())
            let modeStr = enable ? "enabled" : "disabled"

            if actuallyEnabled == enable {
                print("[AudioDeviceChannel] ✓ Exclusive mode \(modeStr) for device \(deviceUID) (verified: PID=\(verifyHogPid))")
            } else {
                print("[AudioDeviceChannel] ⚠️  Exclusive mode set but verification mismatch (expected: \(enable), actual: \(actuallyEnabled), PID=\(verifyHogPid))")
            }

            result([
                "success": true,
                "enabled": actuallyEnabled,
                "mode": "hog",
                "deviceId": deviceUID,
                "verified": actuallyEnabled == enable
            ])
        } else {
            // Check if device is already hogged by another process
            if status == kAudioHardwareIllegalOperationError || status == kAudioHardwareBadDeviceError {
                result(FlutterError(
                    code: "DEVICE_IN_USE",
                    message: "Device is already in exclusive use by another application",
                    details: ["deviceId": deviceUID, "osStatus": Int(status)]
                ))
            } else {
                result(FlutterError(
                    code: "EXCLUSIVE_MODE_FAILED",
                    message: "Failed to set exclusive mode",
                    details: ["deviceId": deviceUID, "osStatus": Int(status)]
                ))
            }
        }
    }

    /// Get current audio format (sample rate, bit depth) for a device
    static func getDeviceFormat(deviceUID: String) -> [String: Any]? {
        guard let deviceId = getDeviceIdFromUID(deviceUID: deviceUID) else {
            print("[AudioDeviceChannel] Device \(deviceUID) not found")
            return nil
        }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )

        var streamFormat = AudioStreamBasicDescription()
        var dataSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        let status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &streamFormat
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get stream format for device \(deviceUID): \(status)")
            return nil
        }

        // Get nominal sample rate (what the device claims to support)
        var nominalSampleRate: Float64 = 0
        propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate
        dataSize = UInt32(MemoryLayout<Float64>.size)

        AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &nominalSampleRate
        )

        let formatInfo: [String: Any] = [
            "deviceId": deviceUID,
            "sampleRate": streamFormat.mSampleRate,
            "nominalSampleRate": nominalSampleRate,
            "channels": Int(streamFormat.mChannelsPerFrame),
            "bitDepth": Int(streamFormat.mBitsPerChannel),
            "formatID": streamFormat.mFormatID,
            "isFloat": (streamFormat.mFormatFlags & kAudioFormatFlagIsFloat) != 0,
            "isInteger": (streamFormat.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0,
        ]

        print("[AudioDeviceChannel] Device format: \(Int(nominalSampleRate))Hz, \(streamFormat.mBitsPerChannel)bit, \(streamFormat.mChannelsPerFrame)ch")
        return formatInfo
    }

    // MARK: - Helper Methods

    /// Get AudioDeviceID from device UID string
    private static func getDeviceIdFromUID(deviceUID: String) -> AudioDeviceID? {
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

        guard status == noErr else { return nil }

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

        guard status == noErr else { return nil }

        // Find device with matching UID
        for deviceId in audioDevices {
            propertyAddress.mSelector = kAudioDevicePropertyDeviceUID
            var deviceUIDCF: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)

            status = AudioObjectGetPropertyData(
                deviceId,
                &propertyAddress,
                0,
                nil,
                &uidSize,
                &deviceUIDCF
            )

            if status == noErr, deviceUIDCF as String == deviceUID {
                return deviceId
            }
        }

        return nil
    }

    // MARK: - Phase 3: Advanced Device Metadata

    static func getDeviceMetadata(deviceUID: String) -> [String: Any]? {
        guard let deviceId = getDeviceIdFromUID(deviceUID: deviceUID) else {
            print("[AudioDeviceChannel] Device not found: \(deviceUID)")
            return nil
        }

        var metadata: [String: Any] = [:]

        // Get supported sample rates
        metadata["supportedSampleRates"] = getSupportedSampleRates(deviceId: deviceId)

        // Get transport type and detect DAC chipset / Bluetooth codec
        if let transportType = getTransportType(deviceId: deviceId) {
            metadata["transportType"] = transportType

            if transportType == "USB" {
                // Try to detect USB DAC chipset
                if let chipset = detectUSBChipset(deviceId: deviceId) {
                    metadata["chipset"] = chipset
                }
            } else if transportType == "Bluetooth" {
                // Try to detect Bluetooth codec
                if let codec = detectBluetoothCodec(deviceId: deviceId) {
                    metadata["bluetoothCodec"] = codec
                }
            }
        }

        // Get device capabilities
        metadata["capabilities"] = getDeviceCapabilities(deviceId: deviceId)

        print("[AudioDeviceChannel] Device metadata: \(metadata)")
        return metadata
    }

    static func getSupportedSampleRates(deviceId: AudioDeviceID) -> [Double] {
        var sampleRates: [Double] = []

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get sample rates size")
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioValueRange>.size
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: count)

        status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &ranges
        )

        guard status == noErr else {
            print("[AudioDeviceChannel] Failed to get sample rates")
            return []
        }

        // Extract unique sample rates from ranges
        for range in ranges {
            if range.mMinimum == range.mMaximum {
                sampleRates.append(range.mMinimum)
            } else {
                // Common sample rates in the range
                let commonRates: [Double] = [44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000]
                for rate in commonRates {
                    if rate >= range.mMinimum && rate <= range.mMaximum {
                        sampleRates.append(rate)
                    }
                }
            }
        }

        return Array(Set(sampleRates)).sorted()
    }

    static func getTransportType(deviceId: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &transportType
        )

        guard status == noErr else { return nil }

        switch transportType {
        case kAudioDeviceTransportTypeUSB:
            return "USB"
        case kAudioDeviceTransportTypeBluetooth:
            return "Bluetooth"
        case kAudioDeviceTransportTypeBuiltIn:
            return "Built-in"
        case kAudioDeviceTransportTypePCI:
            return "PCI"
        case kAudioDeviceTransportTypeFireWire:
            return "FireWire"
        case kAudioDeviceTransportTypeThunderbolt:
            return "Thunderbolt"
        case kAudioDeviceTransportTypeHDMI:
            return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort:
            return "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay:
            return "AirPlay"
        case kAudioDeviceTransportTypeVirtual:
            return "Virtual"
        default:
            return "Unknown"
        }
    }

    static func detectUSBChipset(deviceId: AudioDeviceID) -> String? {
        // Try to get device name which sometimes contains chipset info
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, nil, &dataSize)

        guard status == noErr, dataSize > 0 else { return nil }

        // Allocate memory for CFString pointer
        let deviceNamePtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        defer { deviceNamePtr.deallocate() }

        dataSize = UInt32(MemoryLayout<CFString?>.size)
        status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            deviceNamePtr
        )

        guard status == noErr, let deviceName = deviceNamePtr.pointee else { return nil }

        let name = deviceName as String

        // Common DAC chipset detection based on device name
        if name.contains("ESS") || name.contains("Sabre") {
            return "ESS Sabre"
        } else if name.contains("AKM") || name.contains("AK4") {
            return "AKM"
        } else if name.contains("Burr-Brown") || name.contains("PCM") {
            return "Burr-Brown/TI"
        } else if name.contains("Cirrus") || name.contains("CS4") {
            return "Cirrus Logic"
        }

        return nil
    }

    static func detectBluetoothCodec(deviceId: AudioDeviceID) -> String? {
        // On macOS, Bluetooth codec detection is limited
        // We can try to infer from device name or bitrate
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, nil, &dataSize)

        guard status == noErr, dataSize > 0 else { return "AAC (default)" }

        // Allocate memory for CFString pointer
        let deviceNamePtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        defer { deviceNamePtr.deallocate() }

        dataSize = UInt32(MemoryLayout<CFString?>.size)
        status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            deviceNamePtr
        )

        guard status == noErr, let deviceName = deviceNamePtr.pointee else { return "AAC (default)" }

        let name = deviceName as String

        // Try to detect from name
        if name.contains("aptX") {
            return "aptX"
        } else if name.contains("LDAC") {
            return "LDAC"
        }

        // Default macOS Bluetooth codec
        return "AAC"
    }

    static func getDeviceCapabilities(deviceId: AudioDeviceID) -> [String: Any] {
        var capabilities: [String: Any] = [:]

        // Get stream configuration (channels)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        if status == noErr {
            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }

            status = AudioObjectGetPropertyData(
                deviceId,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                bufferList
            )

            if status == noErr {
                var totalChannels: UInt32 = 0
                let buffers = UnsafeBufferPointer<AudioBuffer>(
                    start: &bufferList.pointee.mBuffers,
                    count: Int(bufferList.pointee.mNumberBuffers)
                )

                for buffer in buffers {
                    totalChannels += buffer.mNumberChannels
                }

                capabilities["maxChannels"] = totalChannels
            }
        }

        return capabilities
    }
}
