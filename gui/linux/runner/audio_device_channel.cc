#include "audio_device_channel.h"

#include <cstring>
#include <iostream>
#include <map>
#include <string>
#include <vector>

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

// PulseAudio context state
struct AudioDeviceContext {
  pa_mainloop* mainloop;
  pa_mainloop_api* mainloop_api;
  pa_context* context;
  std::vector<FlValue*> devices;
  FlValue* default_device;
  bool operation_success;
  std::string error_message;
};

static AudioDeviceContext g_audio_context = {nullptr, nullptr, nullptr, {}, nullptr, false, ""};

// Callback for PulseAudio context state changes
static void context_state_callback(pa_context* context, void* userdata) {
  pa_context_state_t state = pa_context_get_state(context);

  if (state == PA_CONTEXT_READY || state == PA_CONTEXT_FAILED || state == PA_CONTEXT_TERMINATED) {
    // Wake up the mainloop
    pa_mainloop_api* api = (pa_mainloop_api*)userdata;
    api->quit(api, 0);
  }
}

// Initialize PulseAudio connection
static bool initialize_pulse() {
  if (g_audio_context.context && pa_context_get_state(g_audio_context.context) == PA_CONTEXT_READY) {
    return true;  // Already initialized
  }

  // Create mainloop
  g_audio_context.mainloop = pa_mainloop_new();
  if (!g_audio_context.mainloop) {
    std::cerr << "[AudioDeviceChannel] Failed to create PulseAudio mainloop" << std::endl;
    return false;
  }

  g_audio_context.mainloop_api = pa_mainloop_get_api(g_audio_context.mainloop);

  // Create context
  g_audio_context.context = pa_context_new(g_audio_context.mainloop_api, "TrustTune");
  if (!g_audio_context.context) {
    std::cerr << "[AudioDeviceChannel] Failed to create PulseAudio context" << std::endl;
    pa_mainloop_free(g_audio_context.mainloop);
    return false;
  }

  // Connect to server
  pa_context_set_state_callback(g_audio_context.context, context_state_callback, g_audio_context.mainloop_api);

  if (pa_context_connect(g_audio_context.context, nullptr, PA_CONTEXT_NOFLAGS, nullptr) < 0) {
    std::cerr << "[AudioDeviceChannel] Failed to connect to PulseAudio server" << std::endl;
    pa_context_unref(g_audio_context.context);
    pa_mainloop_free(g_audio_context.mainloop);
    return false;
  }

  // Wait for connection
  int ret;
  pa_mainloop_run(g_audio_context.mainloop, &ret);

  pa_context_state_t state = pa_context_get_state(g_audio_context.context);
  if (state != PA_CONTEXT_READY) {
    std::cerr << "[AudioDeviceChannel] PulseAudio context not ready" << std::endl;
    pa_context_disconnect(g_audio_context.context);
    pa_context_unref(g_audio_context.context);
    pa_mainloop_free(g_audio_context.mainloop);
    g_audio_context.context = nullptr;
    return false;
  }

  std::cout << "[AudioDeviceChannel] PulseAudio initialized successfully" << std::endl;
  return true;
}

// Callback for sink (output device) enumeration
static void sink_info_callback(pa_context* context, const pa_sink_info* info, int eol, void* userdata) {
  if (eol > 0) {
    // End of list, wake up mainloop
    pa_mainloop_api* api = (pa_mainloop_api*)userdata;
    api->quit(api, 0);
    return;
  }

  if (!info) return;

  // Create device map
  FlValue* device_map = fl_value_new_map();

  // Device ID
  fl_value_set_string_take(device_map, "id", fl_value_new_string(info->name));
  fl_value_set_string_take(device_map, "deviceId", fl_value_new_string(info->name));

  // Device name
  fl_value_set_string_take(device_map, "name", fl_value_new_string(info->description ? info->description : info->name));

  // Determine transport type from properties
  const char* bus = pa_proplist_gets(info->proplist, PA_PROP_DEVICE_BUS);
  const char* form_factor = pa_proplist_gets(info->proplist, PA_PROP_DEVICE_FORM_FACTOR);

  bool is_usb = bus && (strcmp(bus, "usb") == 0);
  bool is_bluetooth = bus && (strcmp(bus, "bluetooth") == 0);
  bool is_builtin = form_factor && (strcmp(form_factor, "internal") == 0 || strcmp(form_factor, "speaker") == 0);

  std::string transport_type = "other";
  if (is_bluetooth) transport_type = "bluetooth";
  else if (is_usb) transport_type = "usb";
  else if (is_builtin) transport_type = "builtin";

  fl_value_set_string_take(device_map, "transportType", fl_value_new_string(transport_type.c_str()));
  fl_value_set_take(device_map, "isBluetooth", fl_value_new_bool(is_bluetooth));
  fl_value_set_take(device_map, "isUSB", fl_value_new_bool(is_usb));
  fl_value_set_take(device_map, "isBuiltIn", fl_value_new_bool(is_builtin));
  fl_value_set_take(device_map, "isAirPlay", fl_value_new_bool(false));
  fl_value_set_take(device_map, "isOutput", fl_value_new_bool(true));

  g_audio_context.devices.push_back(device_map);
}

// Callback for server info (to get default sink)
static void server_info_callback(pa_context* context, const pa_server_info* info, void* userdata) {
  if (info && info->default_sink_name) {
    // Get full info for default sink
    pa_context_get_sink_info_by_name(context, info->default_sink_name,
      [](pa_context* c, const pa_sink_info* sink_info, int eol, void* ud) {
        if (sink_info && !eol) {
          FlValue* device_map = fl_value_new_map();
          fl_value_set_string_take(device_map, "id", fl_value_new_string(sink_info->name));
          fl_value_set_string_take(device_map, "deviceId", fl_value_new_string(sink_info->name));
          fl_value_set_string_take(device_map, "name", fl_value_new_string(sink_info->description ? sink_info->description : sink_info->name));
          fl_value_set_take(device_map, "isOutput", fl_value_new_bool(true));
          g_audio_context.default_device = device_map;
        }
        if (eol >= 0) {
          pa_mainloop_api* api = (pa_mainloop_api*)ud;
          api->quit(api, 0);
        }
      }, userdata);
  } else {
    pa_mainloop_api* api = (pa_mainloop_api*)userdata;
    api->quit(api, 0);
  }
}

// Enumerate audio devices
static FlValue* enumerate_devices() {
  if (!initialize_pulse()) {
    return fl_value_new_list();
  }

  g_audio_context.devices.clear();

  // Request sink list
  pa_operation* op = pa_context_get_sink_info_list(g_audio_context.context, sink_info_callback, g_audio_context.mainloop_api);
  if (op) {
    int ret;
    pa_mainloop_run(g_audio_context.mainloop, &ret);
    pa_operation_unref(op);
  }

  // Create list from collected devices
  FlValue* device_list = fl_value_new_list();
  for (FlValue* device : g_audio_context.devices) {
    fl_value_append_take(device_list, device);
  }

  std::cout << "[AudioDeviceChannel] Enumerated " << g_audio_context.devices.size() << " devices" << std::endl;
  g_audio_context.devices.clear();

  return device_list;
}

// Get default output device
static FlValue* get_default_device() {
  if (!initialize_pulse()) {
    return fl_value_new_null();
  }

  g_audio_context.default_device = nullptr;

  // Get server info to find default sink
  pa_operation* op = pa_context_get_server_info(g_audio_context.context, server_info_callback, g_audio_context.mainloop_api);
  if (op) {
    int ret;
    pa_mainloop_run(g_audio_context.mainloop, &ret);
    pa_operation_unref(op);
  }

  if (g_audio_context.default_device) {
    FlValue* result = g_audio_context.default_device;
    g_audio_context.default_device = nullptr;
    std::cout << "[AudioDeviceChannel] Default device retrieved" << std::endl;
    return result;
  }

  return fl_value_new_null();
}

// Set audio device (PulseAudio uses sink names)
static FlValue* set_audio_device(const char* device_id) {
  std::cout << "[AudioDeviceChannel] SetAudioDevice called for: " << device_id << std::endl;
  std::cout << "[AudioDeviceChannel] Note: Device selection handled by MediaKit/MPV" << std::endl;

  FlValue* response = fl_value_new_map();
  fl_value_set_take(response, "success", fl_value_new_bool(true));
  return response;
}

// Method call handler
static FlMethodResponse* handle_method_call(FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  std::cout << "[AudioDeviceChannel] Method called: " << method << std::endl;

  if (strcmp(method, kEnumerateDevicesMethod) == 0) {
    FlValue* devices = enumerate_devices();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(devices));
  }
  else if (strcmp(method, kGetDefaultDeviceMethod) == 0) {
    FlValue* default_device = get_default_device();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(default_device));
  }
  else if (strcmp(method, kSetAudioDeviceMethod) == 0) {
    FlValue* device_id_value = fl_value_lookup_string(args, "deviceId");
    if (device_id_value && fl_value_get_type(device_id_value) == FL_VALUE_TYPE_STRING) {
      const char* device_id = fl_value_get_string(device_id_value);
      FlValue* result = set_audio_device(device_id);
      return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGS", "Missing deviceId", nullptr));
  }
  else if (strcmp(method, kSupportsExclusiveModeMethod) == 0) {
    // PulseAudio doesn't have exclusive mode like WASAPI
    FlValue* response = fl_value_new_map();
    fl_value_set_take(response, "supported", fl_value_new_bool(false));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(response));
  }
  else if (strcmp(method, kEnableExclusiveModeMethod) == 0) {
    // Not supported
    FlValue* response = fl_value_new_map();
    fl_value_set_take(response, "success", fl_value_new_bool(false));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(response));
  }
  else if (strcmp(method, kGetDeviceFormatMethod) == 0) {
    // TODO: Get device format from PulseAudio
    FlValue* format = fl_value_new_map();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(format));
  }
  else if (strcmp(method, kGetDeviceMetadataMethod) == 0) {
    // TODO: Get device metadata
    FlValue* metadata = fl_value_new_map();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(metadata));
  }

  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

// Register the audio device channel
void audio_device_channel_register(FlPluginRegistry* registry) {
  FlBinaryMessenger* messenger = fl_plugin_registry_get_messenger(registry);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      messenger,
      kChannelName,
      FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(
      channel,
      [](FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
        FlMethodResponse* response = handle_method_call(method_call);
        g_autoptr(GError) error = nullptr;
        if (!fl_method_call_respond(method_call, response, &error)) {
          g_warning("Failed to send method call response: %s", error->message);
        }
      },
      nullptr,
      nullptr);

  std::cout << "[AudioDeviceChannel] Registered method channel" << std::endl;
}
