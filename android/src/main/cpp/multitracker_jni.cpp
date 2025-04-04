#include <jni.h>
#include <string>
#include <android/log.h>
#include "audio_engine.h"
#include "instrument_manager.h"
#include "sequence_manager.h"

#define LOG_TAG "MultiTrackerJNI"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global instances
static AudioEngine* g_audioEngine = nullptr;
static InstrumentManager* g_instrumentManager = nullptr;
static SequenceManager* g_sequenceManager = nullptr;

// Initialize the audio engine
extern "C" JNIEXPORT jboolean JNICALL
Java_com_raybsou_flutter_1multitracker_SimpleAudioEngine_setupAudioEngine(
        JNIEnv* env,
        jobject /* this */,
        jint sampleRate) {
    
    LOGI("JNI: Setting up audio engine with sample rate %d", sampleRate);
    
    try {
        // Create audio engine
        g_audioEngine = new AudioEngine();
        if (!g_audioEngine) {
            LOGE("JNI: Failed to create audio engine");
            return JNI_FALSE;
        }
        
        // Initialize audio engine
        if (!g_audioEngine->init(sampleRate)) {
            LOGE("JNI: Failed to initialize audio engine");
            delete g_audioEngine;
            g_audioEngine = nullptr;
            return JNI_FALSE;
        }
        
        // Get the instrument manager
        g_instrumentManager = g_audioEngine->getInstrumentManager();
        if (!g_instrumentManager) {
            LOGE("JNI: Failed to get instrument manager");
            delete g_audioEngine;
            g_audioEngine = nullptr;
            return JNI_FALSE;
        }
        
        // Get the sequence manager
        g_sequenceManager = g_audioEngine->getSequenceManager();
        if (!g_sequenceManager) {
            LOGE("JNI: Failed to get sequence manager");
            delete g_audioEngine;
            g_audioEngine = nullptr;
            g_instrumentManager = nullptr;
            return JNI_FALSE;
        }
        
        // Create a default sine wave instrument (ID 0)
        int instrumentId = g_instrumentManager->createSineWaveInstrument("Default Sine");
        if (instrumentId != 0) {
            LOGW("JNI: Default instrument ID is %d (expected 0)", instrumentId);
        }
        
        LOGI("JNI: Audio engine setup complete");
        return JNI_TRUE;
    } catch (const std::exception& e) {
        LOGE("JNI: Exception in setupAudioEngine: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("JNI: Unknown exception in setupAudioEngine");
        return JNI_FALSE;
    }
}

// Create a sine wave instrument
extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_createSineWaveInstrument(
        JNIEnv* env,
        jobject /* this */,
        jstring name) {
    LOGI("Creating sine wave instrument");
    
    if (!g_instrumentManager) {
        LOGE("Instrument manager not initialized");
        return -1;
    }
    
    try {
        const char* nameStr = env->GetStringUTFChars(name, nullptr);
        if (nameStr == nullptr) {
            LOGE("Failed to get instrument name string");
            return -1;
        }
        
        std::string instrumentName(nameStr);
        env->ReleaseStringUTFChars(name, nameStr);
        
        int instrumentId = g_instrumentManager->createSineWaveInstrument(instrumentName);
        LOGI("Created sine wave instrument with ID: %d", instrumentId);
        return instrumentId;
    } catch (const std::exception& e) {
        LOGE("Exception in createSineWaveInstrument: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("Unknown exception in createSineWaveInstrument");
        return -1;
    }
}

// Unload an instrument
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_unloadInstrument(
        JNIEnv* env,
        jobject /* this */,
        jint instrumentId) {
    LOGI("Unloading instrument with ID: %d", instrumentId);
    
    if (!g_instrumentManager) {
        LOGE("Instrument manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_instrumentManager->unloadInstrument(instrumentId);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in unloadInstrument: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in unloadInstrument");
        return JNI_FALSE;
    }
}

// Get loaded instrument IDs
extern "C" JNIEXPORT jintArray JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_getLoadedInstrumentIds(
        JNIEnv* env,
        jobject /* this */) {
    LOGD("Getting loaded instrument IDs");
    
    if (!g_instrumentManager) {
        LOGE("Instrument manager not initialized");
        return env->NewIntArray(0);
    }
    
    try {
        std::vector<int> ids = g_instrumentManager->getLoadedInstrumentIds();
        
        jintArray result = env->NewIntArray(ids.size());
        if (result == nullptr) {
            LOGE("Failed to create int array");
            return env->NewIntArray(0);
        }
        
        if (!ids.empty()) {
            env->SetIntArrayRegion(result, 0, ids.size(), ids.data());
        }
        
        LOGD("Returning %zu instrument IDs", ids.size());
        return result;
    } catch (const std::exception& e) {
        LOGE("Exception in getLoadedInstrumentIds: %s", e.what());
        return env->NewIntArray(0);
    } catch (...) {
        LOGE("Unknown exception in getLoadedInstrumentIds");
        return env->NewIntArray(0);
    }
}

// Set instrument volume
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_setInstrumentVolume(
        JNIEnv* env,
        jobject /* this */,
        jint instrumentId,
        jfloat volume) {
    LOGD("Setting instrument %d volume to %f", instrumentId, volume);
    
    if (!g_instrumentManager) {
        LOGE("Instrument manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_instrumentManager->setInstrumentVolume(instrumentId, volume);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in setInstrumentVolume: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in setInstrumentVolume");
        return JNI_FALSE;
    }
}

// Create a sequence
extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_createSequence(
        JNIEnv* env,
        jobject /* this */,
        jint tempo) {
    LOGI("Creating sequence with tempo: %d", tempo);
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return -1;
    }
    
    try {
        int sequenceId = g_sequenceManager->createSequence(tempo);
        LOGI("Created sequence with ID: %d", sequenceId);
        return sequenceId;
    } catch (const std::exception& e) {
        LOGE("Exception in createSequence: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("Unknown exception in createSequence");
        return -1;
    }
}

// Delete a sequence
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_deleteSequence(
        JNIEnv* env,
        jobject /* this */,
        jint sequenceId) {
    LOGI("Deleting sequence with ID: %d", sequenceId);
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_sequenceManager->deleteSequence(sequenceId);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in deleteSequence: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in deleteSequence");
        return JNI_FALSE;
    }
}

// Add a track to a sequence
extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_addTrack(
        JNIEnv* env,
        jobject /* this */,
        jint sequenceId,
        jint instrumentId) {
    LOGI("Adding track to sequence %d with instrument %d", sequenceId, instrumentId);
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return -1;
    }
    
    try {
        int trackId = g_sequenceManager->addTrack(sequenceId, instrumentId);
        LOGI("Added track with ID: %d", trackId);
        return trackId;
    } catch (const std::exception& e) {
        LOGE("Exception in addTrack: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("Unknown exception in addTrack");
        return -1;
    }
}

// Delete a track from a sequence
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_deleteTrack(
        JNIEnv* env,
        jobject /* this */,
        jint sequenceId,
        jint trackId) {
    LOGI("Deleting track %d from sequence %d", trackId, sequenceId);
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_sequenceManager->deleteTrack(sequenceId, trackId);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in deleteTrack: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in deleteTrack");
        return JNI_FALSE;
    }
}

// Add a note to a track
extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_addNote(
        JNIEnv* env,
        jobject /* this */,
        jint sequenceId,
        jint trackId,
        jint noteNumber,
        jint velocity,
        jdouble startTime,
        jdouble duration) {
    LOGI("Adding note to sequence %d, track %d: note=%d, velocity=%d, start=%f, duration=%f",
         sequenceId, trackId, noteNumber, velocity, startTime, duration);
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return -1;
    }
    
    try {
        int noteId = g_sequenceManager->addNote(sequenceId, trackId, noteNumber, velocity, startTime, duration);
        if (noteId >= 0) {
            LOGI("Added note with ID: %d", noteId);
        } else {
            LOGW("Failed to add note");
        }
        return noteId;
    } catch (const std::exception& e) {
        LOGE("Exception in addNote: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("Unknown exception in addNote");
        return -1;
    }
}

// Delete a note from a track
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_deleteNote(
        JNIEnv* env,
        jobject /* this */,
        jint sequenceId,
        jint trackId,
        jint noteId) {
    LOGI("Deleting note %d from sequence %d, track %d", noteId, sequenceId, trackId);
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_sequenceManager->deleteNote(sequenceId, trackId, noteId);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in deleteNote: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in deleteNote");
        return JNI_FALSE;
    }
}

// Start playback of a sequence
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_startPlayback(
        JNIEnv* env,
        jobject /* this */,
        jint sequenceId) {
    LOGI("Starting playback of sequence %d", sequenceId);
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_sequenceManager->startPlayback(sequenceId);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in startPlayback: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in startPlayback");
        return JNI_FALSE;
    }
}

// Stop playback
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1multitracker_FlutterMultitrackerPlugin_stopPlayback(
        JNIEnv* env,
        jobject /* this */) {
    LOGI("Stopping playback");
    
    if (!g_sequenceManager) {
        LOGE("Sequence manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_sequenceManager->stopPlayback();
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("Exception in stopPlayback: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("Unknown exception in stopPlayback");
        return JNI_FALSE;
    }
}

// Send a note on message
extern "C" JNIEXPORT jboolean JNICALL
Java_com_raybsou_flutter_1multitracker_SimpleAudioEngine_nativePlayNote(
        JNIEnv* env,
        jobject /* this */,
        jint instrumentId,
        jint noteNumber,
        jint velocity) {
    
    LOGI("JNI: Playing note %d with velocity %d on instrument %d", noteNumber, velocity, instrumentId);
    
    if (!g_instrumentManager) {
        LOGE("JNI: Instrument manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_instrumentManager->sendNoteOn(instrumentId, noteNumber, velocity);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("JNI: Exception in playNote: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("JNI: Unknown exception in playNote");
        return JNI_FALSE;
    }
}

// Send a note off message
extern "C" JNIEXPORT jboolean JNICALL
Java_com_raybsou_flutter_1multitracker_SimpleAudioEngine_nativeStopNote(
        JNIEnv* env,
        jobject /* this */,
        jint instrumentId,
        jint noteNumber) {
    
    LOGI("JNI: Stopping note %d on instrument %d", noteNumber, instrumentId);
    
    if (!g_instrumentManager) {
        LOGE("JNI: Instrument manager not initialized");
        return JNI_FALSE;
    }
    
    try {
        bool success = g_instrumentManager->sendNoteOff(instrumentId, noteNumber);
        return success ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        LOGE("JNI: Exception in stopNote: %s", e.what());
        return JNI_FALSE;
    } catch (...) {
        LOGE("JNI: Unknown exception in stopNote");
        return JNI_FALSE;
    }
}

// Clean up resources
extern "C" JNIEXPORT void JNICALL
Java_com_raybsou_flutter_1multitracker_SimpleAudioEngine_nativeCleanup(
        JNIEnv* env,
        jobject /* this */) {
    
    LOGI("JNI: Cleaning up native resources");
    
    try {
        // Clean up sequence manager
        if (g_sequenceManager) {
            delete g_sequenceManager;
            g_sequenceManager = nullptr;
        }
        
        // Clean up instrument manager
        if (g_instrumentManager) {
            g_instrumentManager = nullptr; // Don't delete, it's owned by the audio engine
        }
        
        // Clean up audio engine (this will also clean up the instrument manager)
        if (g_audioEngine) {
            delete g_audioEngine;
            g_audioEngine = nullptr;
        }
        
        LOGI("JNI: All native resources cleaned up");
    } catch (const std::exception& e) {
        LOGE("JNI: Exception in cleanup: %s", e.what());
    } catch (...) {
        LOGE("JNI: Unknown exception in cleanup");
    }
} 