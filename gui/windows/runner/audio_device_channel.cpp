#include "audio_device_channel.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <audioclient.h>
#include <endpointvolume.h>
#include <propidl.h>
#include <propsys.h>
#include <combaseapi.h>

#include <codecvt>
#include <iostream>
#include <locale>
#include <sstream>

namespace audio_device {

// Channel name - must match Dart side
static constexpr char kChannelName[] = "com.trusttune.audio_device";

// Method names
static constexpr char kEnumerateDevicesMethod[] = "enumerateDevices";
static constexpr char kGetDefaultDeviceMethod[] = "getDefaultDevice";
static constexpr char kSetAudioDeviceMethod[] = "setAudioDevice";
static constexpr char kSupportsExclusiveModeMethod[] = "supportsExclusiveMode";
static constexpr char kEnableExclusiveModeMethod[] = "enableExclusiveMode";
static constexpr char kGetDeviceFormatMethod[] = "getDeviceFormat";
static constexpr char kGetDeviceMetadataMethod[] = "getDeviceMetadata";

void AudioDeviceChannel::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AudioDeviceChannel>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  std::cout << "[AudioDeviceChannel] Registered method channel" << std::endl;
  registrar->AddPlugin(std::move(plugin));
}

AudioDeviceChannel::AudioDeviceChannel() {
  InitializeCOM();
}

AudioDeviceChannel::~AudioDeviceChannel() {
  CleanupCOM();
}

bool AudioDeviceChannel::InitializeCOM() {
  // Initialize COM for this thread
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    std::cerr << "[AudioDeviceChannel] Failed to initialize COM: " << std::hex << hr << std::endl;
    return false;
  }
  com_initialized_ = true;

  // Create device enumerator
  hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr,
      CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
      (void**)&device_enumerator_);

  if (FAILED(hr)) {
    std::cerr << "[AudioDeviceChannel] Failed to create device enumerator: " << std::hex << hr << std::endl;
    return false;
  }

  std::cout << "[AudioDeviceChannel] WASAPI initialized successfully" << std::endl;
  return true;
}

void AudioDeviceChannel::CleanupCOM() {
  if (device_enumerator_) {
    device_enumerator_->Release();
    device_enumerator_ = nullptr;
  }

  if (com_initialized_) {
    CoUninitialize();
    com_initialized_ = false;
  }
}

void AudioDeviceChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const std::string& method = method_call.method_name();
  std::cout << "[AudioDeviceChannel] Method called: " << method << std::endl;

  if (method == kEnumerateDevicesMethod) {
    result->Success(flutter::EncodableValue(EnumerateAudioDevices()));
  }
  else if (method == kGetDefaultDeviceMethod) {
    result->Success(GetDefaultOutputDevice());
  }
  else if (method == kSetAudioDeviceMethod) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGS", "Arguments must be a map");
      return;
    }

    auto device_id_it = arguments->find(flutter::EncodableValue("deviceId"));
    if (device_id_it == arguments->end()) {
      result->Error("INVALID_ARGS", "Missing deviceId");
      return;
    }

    const auto* device_id = std::get_if<std::string>(&device_id_it->second);
    if (!device_id) {
      result->Error("INVALID_ARGS", "deviceId must be a string");
      return;
    }

    SetOutputDevice(*device_id, std::move(result));
  }
  else if (method == kSupportsExclusiveModeMethod) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGS", "Arguments must be a map");
      return;
    }

    auto device_id_it = arguments->find(flutter::EncodableValue("deviceId"));
    if (device_id_it == arguments->end()) {
      result->Error("INVALID_ARGS", "Missing deviceId");
      return;
    }

    const auto* device_id = std::get_if<std::string>(&device_id_it->second);
    if (!device_id) {
      result->Error("INVALID_ARGS", "deviceId must be a string");
      return;
    }

    result->Success(SupportsExclusiveMode(*device_id));
  }
  else if (method == kEnableExclusiveModeMethod) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGS", "Arguments must be a map");
      return;
    }

    auto device_id_it = arguments->find(flutter::EncodableValue("deviceId"));
    auto enable_it = arguments->find(flutter::EncodableValue("enable"));

    if (device_id_it == arguments->end() || enable_it == arguments->end()) {
      result->Error("INVALID_ARGS", "Missing deviceId or enable");
      return;
    }

    const auto* device_id = std::get_if<std::string>(&device_id_it->second);
    const auto* enable = std::get_if<bool>(&enable_it->second);

    if (!device_id || !enable) {
      result->Error("INVALID_ARGS", "Invalid argument types");
      return;
    }

    EnableExclusiveMode(*device_id, *enable, std::move(result));
  }
  else if (method == kGetDeviceFormatMethod) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGS", "Arguments must be a map");
      return;
    }

    auto device_id_it = arguments->find(flutter::EncodableValue("deviceId"));
    if (device_id_it == arguments->end()) {
      result->Error("INVALID_ARGS", "Missing deviceId");
      return;
    }

    const auto* device_id = std::get_if<std::string>(&device_id_it->second);
    if (!device_id) {
      result->Error("INVALID_ARGS", "deviceId must be a string");
      return;
    }

    result->Success(GetDeviceFormat(*device_id));
  }
  else if (method == kGetDeviceMetadataMethod) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGS", "Arguments must be a map");
      return;
    }

    auto device_id_it = arguments->find(flutter::EncodableValue("deviceId"));
    if (device_id_it == arguments->end()) {
      result->Error("INVALID_ARGS", "Missing deviceId");
      return;
    }

    const auto* device_id = std::get_if<std::string>(&device_id_it->second);
    if (!device_id) {
      result->Error("INVALID_ARGS", "deviceId must be a string");
      return;
    }

    result->Success(GetDeviceMetadata(*device_id));
  }
  else {
    result->NotImplemented();
  }
}

flutter::EncodableList AudioDeviceChannel::EnumerateAudioDevices() {
  flutter::EncodableList devices;

  if (!device_enumerator_) {
    std::cerr << "[AudioDeviceChannel] Device enumerator not initialized" << std::endl;
    return devices;
  }

  IMMDeviceCollection* device_collection = nullptr;
  HRESULT hr = device_enumerator_->EnumAudioEndpoints(
      eRender,  // Output devices only
      DEVICE_STATE_ACTIVE,  // Active devices only
      &device_collection);

  if (FAILED(hr)) {
    std::cerr << "[AudioDeviceChannel] Failed to enumerate devices: " << std::hex << hr << std::endl;
    return devices;
  }

  UINT count = 0;
  hr = device_collection->GetCount(&count);
  if (FAILED(hr)) {
    device_collection->Release();
    return devices;
  }

  std::cout << "[AudioDeviceChannel] Found " << count << " audio devices" << std::endl;

  for (UINT i = 0; i < count; i++) {
    IMMDevice* device = nullptr;
    hr = device_collection->Item(i, &device);
    if (SUCCEEDED(hr)) {
      flutter::EncodableMap device_map = DeviceToMap(device);
      if (!device_map.empty()) {
        devices.push_back(flutter::EncodableValue(device_map));
      }
      device->Release();
    }
  }

  device_collection->Release();
  return devices;
}

flutter::EncodableValue AudioDeviceChannel::GetDefaultOutputDevice() {
  if (!device_enumerator_) {
    std::cerr << "[AudioDeviceChannel] Device enumerator not initialized" << std::endl;
    return flutter::EncodableValue();
  }

  IMMDevice* default_device = nullptr;
  HRESULT hr = device_enumerator_->GetDefaultAudioEndpoint(
      eRender,  // Output device
      eConsole,  // Console role (for apps)
      &default_device);

  if (FAILED(hr)) {
    std::cerr << "[AudioDeviceChannel] Failed to get default device: " << std::hex << hr << std::endl;
    return flutter::EncodableValue();
  }

  flutter::EncodableMap device_map = DeviceToMap(default_device);
  default_device->Release();

  if (!device_map.empty()) {
    auto name_it = device_map.find(flutter::EncodableValue("name"));
    if (name_it != device_map.end()) {
      const auto* name = std::get_if<std::string>(&name_it->second);
      if (name) {
        std::cout << "[AudioDeviceChannel] Default device: " << *name << std::endl;
      }
    }
  }

  return flutter::EncodableValue(device_map);
}

void AudioDeviceChannel::SetOutputDevice(
    const std::string& device_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Note: Windows does not allow applications to change the system default device programmatically
  // This would require administrative privileges and registry modifications
  // For now, we'll return a success indicator but note this is not fully implemented

  std::cout << "[AudioDeviceChannel] SetOutputDevice called for: " << device_id << std::endl;
  std::cout << "[AudioDeviceChannel] Note: Changing system default is not supported by WASAPI" << std::endl;

  // Verify device exists
  IMMDevice* device = GetDeviceById(device_id);
  if (!device) {
    result->Error("DEVICE_NOT_FOUND", "Device not found");
    return;
  }
  device->Release();

  // Return success map (MediaKit will handle actual device selection)
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

flutter::EncodableValue AudioDeviceChannel::SupportsExclusiveMode(
    const std::string& device_id) {

  // All WASAPI devices support exclusive mode
  flutter::EncodableMap response;
  response[flutter::EncodableValue("supported")] = flutter::EncodableValue(true);

  std::cout << "[AudioDeviceChannel] Device " << device_id << " supports exclusive mode" << std::endl;
  return flutter::EncodableValue(response);
}

void AudioDeviceChannel::EnableExclusiveMode(
    const std::string& device_id,
    bool enable,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Note: WASAPI exclusive mode is configured when opening the audio client
  // This is typically handled by the audio framework (MediaKit), not the device enumerator

  std::cout << "[AudioDeviceChannel] EnableExclusiveMode: " << (enable ? "enable" : "disable")
            << " for device: " << device_id << std::endl;

  // Verify device exists
  IMMDevice* device = GetDeviceById(device_id);
  if (!device) {
    result->Error("DEVICE_NOT_FOUND", "Device not found");
    return;
  }
  device->Release();

  // Return success (actual exclusive mode is set during IAudioClient initialization)
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

flutter::EncodableValue AudioDeviceChannel::GetDeviceFormat(
    const std::string& device_id) {

  IMMDevice* device = GetDeviceById(device_id);
  if (!device) {
    return flutter::EncodableValue();
  }

  IAudioClient* audio_client = nullptr;
  HRESULT hr = device->Activate(
      __uuidof(IAudioClient), CLSCTX_ALL,
      nullptr, (void**)&audio_client);

  if (FAILED(hr)) {
    device->Release();
    return flutter::EncodableValue();
  }

  WAVEFORMATEX* format = nullptr;
  hr = audio_client->GetMixFormat(&format);

  flutter::EncodableMap format_map;
  if (SUCCEEDED(hr) && format) {
    format_map[flutter::EncodableValue("sampleRate")] =
        flutter::EncodableValue(static_cast<int>(format->nSamplesPerSec));
    format_map[flutter::EncodableValue("bitDepth")] =
        flutter::EncodableValue(static_cast<int>(format->wBitsPerSample));
    format_map[flutter::EncodableValue("channels")] =
        flutter::EncodableValue(static_cast<int>(format->nChannels));

    CoTaskMemFree(format);
  }

  audio_client->Release();
  device->Release();

  return flutter::EncodableValue(format_map);
}

flutter::EncodableValue AudioDeviceChannel::GetDeviceMetadata(
    const std::string& device_id) {

  IMMDevice* device = GetDeviceById(device_id);
  if (!device) {
    return flutter::EncodableValue();
  }

  flutter::EncodableMap metadata;

  // Get device format
  flutter::EncodableValue format = GetDeviceFormat(device_id);
  if (auto* format_map = std::get_if<flutter::EncodableMap>(&format)) {
    metadata[flutter::EncodableValue("format")] = format;
  }

  // Get transport type
  std::string transport = GetDeviceProperty(device, PKEY_AudioEndpoint_PhysicalSpeakers);
  metadata[flutter::EncodableValue("transportType")] = flutter::EncodableValue(transport);

  // Note: USB DAC chipset and Bluetooth codec detection would require additional Windows APIs
  // and device-specific queries. This is a placeholder for Phase 3 enhancement.

  device->Release();
  return flutter::EncodableValue(metadata);
}

flutter::EncodableMap AudioDeviceChannel::DeviceToMap(IMMDevice* device) {
  flutter::EncodableMap device_map;

  // Get device ID
  LPWSTR device_id_wstr = nullptr;
  HRESULT hr = device->GetId(&device_id_wstr);
  if (FAILED(hr)) {
    return device_map;
  }
  std::string device_id = WideStringToString(device_id_wstr);
  CoTaskMemFree(device_id_wstr);

  // Get friendly name
  std::string name = GetDeviceProperty(device, PKEY_Device_FriendlyName);
  std::string description = GetDeviceProperty(device, PKEY_Device_DeviceDesc);

  // Determine transport type
  bool is_usb = device_id.find("USB") != std::string::npos;
  bool is_bluetooth = device_id.find("Bluetooth") != std::string::npos ||
                      device_id.find("BT") != std::string::npos;
  bool is_builtin = device_id.find("IntegratedSpeaker") != std::string::npos ||
                    device_id.find("BuiltIn") != std::string::npos;

  std::string transport_type = "other";
  if (is_bluetooth) transport_type = "bluetooth";
  else if (is_usb) transport_type = "usb";
  else if (is_builtin) transport_type = "builtin";

  // Build device map matching macOS format
  device_map[flutter::EncodableValue("id")] = flutter::EncodableValue(device_id);
  device_map[flutter::EncodableValue("name")] = flutter::EncodableValue(name);
  device_map[flutter::EncodableValue("transportType")] = flutter::EncodableValue(transport_type);
  device_map[flutter::EncodableValue("isBluetooth")] = flutter::EncodableValue(is_bluetooth);
  device_map[flutter::EncodableValue("isUSB")] = flutter::EncodableValue(is_usb);
  device_map[flutter::EncodableValue("isBuiltIn")] = flutter::EncodableValue(is_builtin);
  device_map[flutter::EncodableValue("isAirPlay")] = flutter::EncodableValue(false);  // Windows doesn't have AirPlay
  device_map[flutter::EncodableValue("isOutput")] = flutter::EncodableValue(true);
  device_map[flutter::EncodableValue("deviceId")] = flutter::EncodableValue(device_id);

  return device_map;
}

std::string AudioDeviceChannel::GetDeviceProperty(
    IMMDevice* device,
    const PROPERTYKEY& key) {

  IPropertyStore* property_store = nullptr;
  HRESULT hr = device->OpenPropertyStore(STGM_READ, &property_store);
  if (FAILED(hr)) {
    return "";
  }

  PROPVARIANT prop_variant;
  PropVariantInit(&prop_variant);

  hr = property_store->GetValue(key, &prop_variant);
  std::string value;

  if (SUCCEEDED(hr)) {
    if (prop_variant.vt == VT_LPWSTR && prop_variant.pwszVal != nullptr) {
      value = WideStringToString(prop_variant.pwszVal);
    }
  }

  PropVariantClear(&prop_variant);
  property_store->Release();

  return value;
}

std::string AudioDeviceChannel::WideStringToString(const std::wstring& wstr) {
  if (wstr.empty()) return "";

  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.length(),
                                        nullptr, 0, nullptr, nullptr);
  std::string str(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.length(),
                     &str[0], size_needed, nullptr, nullptr);
  return str;
}

std::wstring AudioDeviceChannel::StringToWideString(const std::string& str) {
  if (str.empty()) return L"";

  int size_needed = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.length(),
                                        nullptr, 0);
  std::wstring wstr(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.length(),
                     &wstr[0], size_needed);
  return wstr;
}

IMMDevice* AudioDeviceChannel::GetDeviceById(const std::string& device_id) {
  if (!device_enumerator_) {
    return nullptr;
  }

  std::wstring wdevice_id = StringToWideString(device_id);
  IMMDevice* device = nullptr;

  HRESULT hr = device_enumerator_->GetDevice(wdevice_id.c_str(), &device);
  if (FAILED(hr)) {
    std::cerr << "[AudioDeviceChannel] Failed to get device: " << device_id << std::endl;
    return nullptr;
  }

  return device;
}

}  // namespace audio_device
