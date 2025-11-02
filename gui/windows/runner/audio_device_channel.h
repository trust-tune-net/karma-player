#ifndef RUNNER_AUDIO_DEVICE_CHANNEL_H_
#define RUNNER_AUDIO_DEVICE_CHANNEL_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

#include <windows.h>
#include <mmdeviceapi.h>
#include <Functiondiscoverykeys_devpkey.h>

namespace audio_device {

class AudioDeviceChannel {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  AudioDeviceChannel();
  virtual ~AudioDeviceChannel();

  // Prevent copying
  AudioDeviceChannel(AudioDeviceChannel const&) = delete;
  AudioDeviceChannel& operator=(AudioDeviceChannel const&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // WASAPI audio device enumeration
  flutter::EncodableList EnumerateAudioDevices();
  flutter::EncodableValue GetDefaultOutputDevice();
  void SetOutputDevice(const std::string& device_id,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // WASAPI Exclusive Mode (Phase 2)
  flutter::EncodableValue SupportsExclusiveMode(const std::string& device_id);
  void EnableExclusiveMode(const std::string& device_id,
                          bool enable,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Advanced Device Info (Phase 3)
  flutter::EncodableValue GetDeviceFormat(const std::string& device_id);
  flutter::EncodableValue GetDeviceMetadata(const std::string& device_id);

  // Helper methods
  flutter::EncodableMap DeviceToMap(IMMDevice* device);
  std::string GetDeviceProperty(IMMDevice* device, const PROPERTYKEY& key);
  std::string WideStringToString(const std::wstring& wstr);
  std::wstring StringToWideString(const std::string& str);
  IMMDevice* GetDeviceById(const std::string& device_id);

  // COM initialization
  bool InitializeCOM();
  void CleanupCOM();

  // Member variables
  IMMDeviceEnumerator* device_enumerator_ = nullptr;
  bool com_initialized_ = false;
};

}  // namespace audio_device

#endif  // RUNNER_AUDIO_DEVICE_CHANNEL_H_
