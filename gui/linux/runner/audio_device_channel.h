#ifndef RUNNER_AUDIO_DEVICE_CHANNEL_H_
#define RUNNER_AUDIO_DEVICE_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>
#include <pulse/pulseaudio.h>

G_BEGIN_DECLS

// Registers the audio device channel with the Flutter engine
void audio_device_channel_register(FlPluginRegistry* registry);

G_END_DECLS

#endif  // RUNNER_AUDIO_DEVICE_CHANNEL_H_
