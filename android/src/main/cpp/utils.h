#ifndef MULTITRACKER_UTILS_H
#define MULTITRACKER_UTILS_H

#include <android/log.h>
#include <cmath>

// Define log macros
#define LOG_TAG "MultiTracker"

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Define M_PI if not already defined
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// MIDI note to frequency conversion
inline float midiNoteToFrequency(int note) {
    return 440.0f * std::pow(2.0f, (note - 69.0f) / 12.0f);
}

#endif // MULTITRACKER_UTILS_H 