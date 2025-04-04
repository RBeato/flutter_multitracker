#include <cstdint>
#include <cstring>
#include <string>
#include <jni.h>
#include <android/log.h>
#include <memory>
#include <atomic>
#include <thread>
#include <mutex>
#include <chrono>

#include "audio_engine.h"
#include "instrument_manager.h"
#include "sequence_manager.h"
#include "utils.h"

#define LOG_TAG "MultiTrackerFFI"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Atomic flag for initialization state
std::atomic<bool> g_initialized(false);

// Global objects
AudioEngine* g_audioEngine = nullptr;
InstrumentManager* g_instrumentManager = nullptr;
SequenceManager* g_sequenceManager = nullptr;

// Mutex for thread safety
static std::mutex g_mutex;

// Dart port for callbacks
static int64_t g_dart_port = 0;

// Constants
#define FFI_SUCCESS 1
#define FFI_FAILURE 0

// Handle errors
int8_t handleError(const char* errorMsg) {
    LOGE("FFI Error: %s", errorMsg);
    return 0;
}

// FFI exported functions
extern "C" {

// Test initialization function for FFI
extern "C" JNIEXPORT int8_t JNICALL
test_init() {
    LOGI("Testing FFI initialization");
    return 1; // Return 1 for success
}

// Register Dart callback port for FFI
extern "C" JNIEXPORT void* JNICALL
register_dart_callback_port(int64_t port) {
    LOGI("FFI: Registering Dart callback port: %lld", (long long)port);
    g_dart_port = port;
    return (void*)1; // Return non-null pointer to indicate success
}

// Initialize the audio engine
extern "C" JNIEXPORT int8_t JNICALL
init_audio_engine(int32_t sample_rate) {
    LOGI("FFI: Initializing with sample rate %d", sample_rate);
    
    try {
        // Check if already initialized
        if (g_initialized.load()) {
            LOGW("FFI: Already initialized");
            return 1; // Already initialized
        }
        
        // Create audio engine
        LOGI("FFI: Creating audio engine");
        g_audioEngine = new AudioEngine();
        if (!g_audioEngine) {
            LOGE("FFI: Failed to create audio engine");
            return -1;
        }
        
        // Initialize audio engine with sample rate
        LOGI("FFI: Initializing audio engine");
        if (!g_audioEngine->init(sample_rate)) {
            LOGE("FFI: Failed to initialize audio engine");
            delete g_audioEngine;
            g_audioEngine = nullptr;
            return -1;
        }
        
        // Get instrument manager
        LOGI("FFI: Getting instrument manager");
        g_instrumentManager = g_audioEngine->getInstrumentManager();
        if (!g_instrumentManager) {
            LOGE("FFI: Failed to get instrument manager");
            delete g_audioEngine;
            g_audioEngine = nullptr;
            return -1;
        }
        
        // Get sequence manager
        LOGI("FFI: Getting sequence manager");
        g_sequenceManager = g_audioEngine->getSequenceManager();
        if (!g_sequenceManager) {
            LOGE("FFI: Failed to get sequence manager");
            delete g_audioEngine;
            g_audioEngine = nullptr;
            g_instrumentManager = nullptr;
            return -1;
        }
        
        // Create a default sine wave instrument for testing
        LOGI("FFI: Creating default sine wave instrument");
        int instrumentId = g_instrumentManager->createSineWaveInstrument("Default Sine Wave");
        if (instrumentId < 0) {
            LOGW("FFI: Failed to create default sine wave instrument, but continuing anyway");
        } else {
            LOGI("FFI: Created default sine wave instrument with ID %d", instrumentId);
        }
        
        // Mark as initialized
        LOGI("FFI: Initialization complete");
        g_initialized.store(true);
        return 1;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception in initialize: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("FFI: Unknown exception in initialize");
        return -1;
    }
}

// Start the audio engine
extern "C" JNIEXPORT int8_t JNICALL
start_audio_engine() {
    LOGI("FFI: Starting audio engine");
    
    if (!g_initialized) {
        LOGE("FFI: Audio engine not initialized");
        return 0;
    }
    
    std::lock_guard<std::mutex> lock(g_mutex);
    
    try {
        if (!g_audioEngine) {
            LOGE("FFI: Audio engine not created");
            return 0;
        }
        
        if (!g_audioEngine->start()) {
            LOGE("FFI: Failed to start audio engine");
            return 0;
        }
        
        LOGI("FFI: Audio engine started successfully");
        return 1;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when starting audio engine: %s", e.what());
        return 0;
    } catch (...) {
        LOGE("FFI: Unknown exception when starting audio engine");
        return 0;
    }
}

// Stop the audio engine
extern "C" JNIEXPORT int8_t JNICALL
stop_audio_engine() {
    LOGI("FFI: Stopping audio engine");
    
    if (!g_initialized.load()) {
        LOGE("FFI: Audio engine not initialized");
        return 0;
    }
    
    try {
        std::lock_guard<std::mutex> lock(g_mutex);
        
        if (g_audioEngine) {
            // Stop the audio engine (void return type)
            g_audioEngine->stop();
            LOGI("FFI: Audio engine stopped");
        } else {
            LOGE("FFI: Audio engine not created");
            return 0;
        }
        
        return 1;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception in stop_audio_engine: %s", e.what());
        return 0;
    } catch (...) {
        LOGE("FFI: Unknown exception in stop_audio_engine");
        return 0;
    }
}

// Dispose all resources
extern "C" JNIEXPORT int8_t JNICALL
dispose() {
    LOGI("FFI: Disposing resources");
    
    try {
        std::lock_guard<std::mutex> lock(g_mutex);
        
        if (g_audioEngine) {
            // Stop the audio engine if it's running
            g_audioEngine->stop();
        }
        
        // Clean up the sequence manager
        if (g_sequenceManager) {
            delete g_sequenceManager;
            g_sequenceManager = nullptr;
        }
        
        // Clean up the instrument manager
        if (g_instrumentManager) {
            delete g_instrumentManager;
            g_instrumentManager = nullptr;
        }
        
        // Clean up the audio engine last
        if (g_audioEngine) {
            delete g_audioEngine;
            g_audioEngine = nullptr;
        }
        
        // Reset initialized flag
        g_initialized.store(false);
        
        LOGI("FFI: Resources disposed successfully");
        return 1;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception during cleanup: %s", e.what());
        return 0;
    } catch (...) {
        LOGE("FFI: Unknown exception during cleanup");
        return 0;
    }
}

// Load an instrument from SFZ file
int32_t load_instrument_sfz(const char* sfzPath) {
    LOGI("FFI: Loading SFZ instrument from: %s", sfzPath);
    
    if (!g_initialized || !g_instrumentManager) {
        LOGE("FFI: Audio engine or instrument manager not initialized");
        return -1;
    }
    
    try {
        // For now, just create a sine wave instrument since we haven't implemented SFZ yet
        int32_t instrumentId = g_instrumentManager->createSineWaveInstrument(std::string(sfzPath));
        if (instrumentId < 0) {
            LOGE("FFI: Failed to load SFZ instrument");
            return -1;
        }
        
        LOGI("FFI: Created sine wave instrument with ID: %d", instrumentId);
        return instrumentId;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when loading SFZ instrument: %s", e.what());
        return -1;
    }
}

// Load an instrument from SF2 file
int32_t load_instrument_sf2(const char* sf2Path, int32_t preset, int32_t bank) {
    LOGI("FFI: Loading SF2 instrument from: %s, preset: %d, bank: %d", sf2Path, preset, bank);
    
    if (!g_initialized || !g_instrumentManager) {
        LOGE("FFI: Audio engine or instrument manager not initialized");
        return -1;
    }
    
    try {
        // For now, just create a sine wave instrument since we haven't implemented SF2 yet
        int32_t instrumentId = g_instrumentManager->createSineWaveInstrument(std::string(sf2Path));
        if (instrumentId < 0) {
            LOGE("FFI: Failed to load SF2 instrument");
            return -1;
        }
        
        LOGI("FFI: Created sine wave instrument with ID: %d", instrumentId);
        return instrumentId;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when loading SF2 instrument: %s", e.what());
        return -1;
    }
}

// Play a note
int8_t play_note(int32_t instrumentId, int32_t note, int32_t velocity) {
    LOGI("FFI: Playing note %d with velocity %d with instrument %d", note, velocity, instrumentId);
    
    if (!g_initialized || !g_instrumentManager) {
        LOGE("FFI: Audio engine or instrument manager not initialized");
        return 0;
    }
    
    try {
        // Verify the instrument exists
        auto instrumentOpt = g_instrumentManager->getInstrument(instrumentId);
        if (!instrumentOpt) {
            LOGE("FFI: Instrument with ID %d not found", instrumentId);
            return 0;
        }
        
        bool success = g_instrumentManager->sendNoteOn(instrumentId, note, velocity);
        LOGI("FFI: Play note result: %s", success ? "success" : "failure");
        return success ? 1 : 0;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when playing note: %s", e.what());
        return 0;
    }
}

// Stop a note
int8_t stop_note(int32_t instrumentId, int32_t note) {
    LOGI("FFI: Stopping note %d with instrument %d", note, instrumentId);
    
    if (!g_initialized || !g_instrumentManager) {
        LOGE("FFI: Audio engine or instrument manager not initialized");
        return 0;
    }
    
    try {
        bool success = g_instrumentManager->sendNoteOff(instrumentId, note);
        LOGI("FFI: Stop note result: %s", success ? "success" : "failure");
        return success ? 1 : 0;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when stopping note: %s", e.what());
        return 0;
    }
}

// Create a sequence
int32_t create_sequence(double bpm, int32_t timeSignatureNumerator, int32_t timeSignatureDenominator) {
    LOGI("FFI: Creating sequence with BPM: %f, time signature: %d/%d", bpm, timeSignatureNumerator, timeSignatureDenominator);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return -1;
    }
    
    try {
        int32_t sequenceId = g_sequenceManager->createSequence(bpm);
        if (sequenceId < 0) {
            LOGE("FFI: Failed to create sequence");
            return -1;
        }
        
        LOGI("FFI: Created sequence with ID: %d", sequenceId);
        return sequenceId;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when creating sequence: %s", e.what());
        return -1;
    }
}

// Add track to sequence
int32_t add_track(int32_t sequenceId, int32_t instrumentId) {
    LOGI("FFI: Adding track with instrument ID %d to sequence ID %d", instrumentId, sequenceId);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return -1;
    }
    
    try {
        int32_t trackId = g_sequenceManager->addTrack(sequenceId, instrumentId);
        if (trackId < 0) {
            LOGE("FFI: Failed to add track to sequence");
            return -1;
        }
        
        LOGI("FFI: Added track with ID: %d", trackId);
        return trackId;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when adding track: %s", e.what());
        return -1;
    }
}

// Add note to track
int8_t add_note(int32_t sequenceId, int32_t trackId, int32_t noteNumber, 
               int32_t velocity, double startBeat, double durationBeats) {
    LOGI("FFI: Adding note to track %d in sequence %d: note=%d, vel=%d, start=%f, dur=%f", 
         trackId, sequenceId, noteNumber, velocity, startBeat, durationBeats);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return 0;
    }
    
    try {
        bool success = g_sequenceManager->addNote(sequenceId, trackId, noteNumber, velocity, startBeat, durationBeats);
        return success ? 1 : 0;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when adding note: %s", e.what());
        return 0;
    }
}

// Play a sequence
int8_t play_sequence(int32_t sequenceId, int8_t loop) {
    LOGI("FFI: Playing sequence %d, loop=%d", sequenceId, loop);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return 0;
    }
    
    try {
        bool success = g_sequenceManager->startPlayback(sequenceId);
        return success ? 1 : 0;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when playing sequence: %s", e.what());
        return 0;
    }
}

// Stop a sequence
int8_t stop_sequence(int32_t sequenceId) {
    LOGI("FFI: Stopping sequence %d", sequenceId);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return 0;
    }
    
    try {
        bool success = g_sequenceManager->stopPlayback();
        return success ? 1 : 0;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when stopping sequence: %s", e.what());
        return 0;
    }
}

// Delete a sequence
int8_t delete_sequence(int32_t sequenceId) {
    LOGI("FFI: Deleting sequence %d", sequenceId);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return 0;
    }
    
    try {
        bool success = g_sequenceManager->deleteSequence(sequenceId);
        return success ? 1 : 0;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when deleting sequence: %s", e.what());
        return 0;
    }
}

// Set playback position
int8_t set_playback_position(int32_t sequenceId, double beat) {
    LOGI("FFI: Setting playback position for sequence %d to beat %f", sequenceId, beat);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return 0;
    }
    
    try {
        return 1;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when setting playback position: %s", e.what());
        return 0;
    }
}

// Get playback position
float get_playback_position(int32_t sequenceId) {
    LOGD("FFI: Getting playback position for sequence %d", sequenceId);
    
    if (!g_initialized || !g_sequenceManager) {
        LOGE("FFI: Audio engine or sequence manager not initialized");
        return -1.0f;
    }
    
    try {
        return 0.0f;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when getting playback position: %s", e.what());
        return -1.0f;
    }
}

// No longer implemented - always returns success
extern "C" JNIEXPORT int8_t JNICALL
set_master_volume(float volume) {
    LOGI("FFI: Setting master volume is not supported in this version");
    return 1; // Success (even though it's not implemented)
}

// Set track volume - not directly supported in current API
int8_t set_track_volume(int32_t sequenceId, int32_t trackId, float volume) {
    // TODO: Implement when track volume control is available
    return 1; // Return success for now
}

// Play a test tone
int8_t play_test_tone() {
    LOGI("FFI: Playing test tone");
    
    try {
        // Check if initialized
        if (!g_initialized.load()) {
            LOGE("FFI: Not initialized");
            return 0;
        }
        
        // Check if we have an audio engine
        if (!g_audioEngine) {
            LOGE("FFI: No audio engine");
            return 0;
        }
        
        // Check if we have an instrument manager
        if (!g_instrumentManager) {
            LOGE("FFI: No instrument manager");
            return 0;
        }
        
        // Try to play a note on the default instrument (ID 0)
        LOGI("FFI: Sending note on event");
        bool result = g_instrumentManager->sendNoteOn(0, 60, 100);
        LOGI("FFI: Play test tone result: %s", result ? "true" : "false");
        return result ? 1 : 0;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception in play_test_tone: %s", e.what());
        return 0;
    } catch (...) {
        LOGE("FFI: Unknown exception in play_test_tone");
        return 0;
    }
}

// Stop the test tone
int8_t stop_test_tone() {
    LOGI("FFI: Stopping test tone");
    
    if (!g_initialized.load() || !g_audioEngine || !g_instrumentManager) {
        LOGE("FFI: Audio engine or instrument manager not initialized");
        return 0;
    }
    
    try {
        // Try to stop all active notes on all instruments
        LOGI("FFI: Stopping all active notes");
        bool success = false;
        
        // Get all instruments
        std::vector<int> instrumentIds = g_instrumentManager->getLoadedInstrumentIds();
        
        // If no instruments found, try with default ID
        if (instrumentIds.empty()) {
            LOGW("FFI: No instruments found, trying with default ID 0");
            instrumentIds.push_back(0);
        }
        
        // Try to stop notes on all instruments
        for (int id : instrumentIds) {
            LOGI("FFI: Stopping notes on instrument %d", id);
            
            // Stop middle C (60) and some surrounding notes to be sure
            for (int note = 58; note <= 62; note++) {
                if (g_instrumentManager->sendNoteOff(id, note)) {
                    LOGI("FFI: Successfully stopped note %d on instrument %d", note, id);
                    success = true;
                }
            }
        }
        
        if (!success) {
            LOGW("FFI: No notes were successfully stopped");
            return 0;
        }
        
        LOGI("FFI: Test tone stopped successfully");
        return 1;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception when stopping test tone: %s", e.what());
        return 0;
    } catch (...) {
        LOGE("FFI: Unknown exception when stopping test tone");
        return 0;
    }
}

// Shut down the audio engine
extern "C" JNIEXPORT int8_t JNICALL
shutdown() {
    LOGI("FFI: Shutting down");
    
    try {
        // Check if initialized
        if (!g_initialized.load()) {
            LOGW("FFI: Not initialized, nothing to shut down");
            return 1; // Nothing to do
        }
        
        // Stop the audio engine
        if (g_audioEngine) {
            LOGI("FFI: Stopping audio engine");
            g_audioEngine->stop();
        }
        
        // Clear the instrument manager pointer (owned by the audio engine)
        LOGI("FFI: Clearing instrument manager reference");
        g_instrumentManager = nullptr;
        
        // Clear the sequence manager pointer (owned by the audio engine)
        LOGI("FFI: Clearing sequence manager reference");
        g_sequenceManager = nullptr;
        
        // Delete the audio engine
        LOGI("FFI: Deleting audio engine");
        delete g_audioEngine;
        g_audioEngine = nullptr;
        
        // Mark as not initialized
        LOGI("FFI: Shutdown complete");
        g_initialized.store(false);
        return 1;
    } catch (const std::exception& e) {
        LOGE("FFI: Exception in shutdown: %s", e.what());
        return 0;
    } catch (...) {
        LOGE("FFI: Unknown exception in shutdown");
        return 0;
    }
}

} // extern "C" 