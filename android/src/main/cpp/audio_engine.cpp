#include "audio_engine.h"
#include "instrument_manager.h"
#include "sequence_manager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>
#include <cstring>
#include <thread>
#include <chrono>

#define LOG_TAG "AudioEngine"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Default buffer size (2 channels * frames)
#define DEFAULT_FRAMES_PER_BUFFER 512

// Forward declaration for the callback function
void bufferQueueCallback(SLAndroidSimpleBufferQueueItf bq /* unused */, void* context);

AudioEngine::AudioEngine()
    : m_isInitialized(false)
    , m_isRunning(false)
    , m_sampleRate(44100)
    , m_engineObj(nullptr)
    , m_engine(nullptr)
    , m_outputMixObj(nullptr)
    , m_playerObj(nullptr)
    , m_player(nullptr)
    , m_bufferQueue(nullptr)
    , m_currentBuffer(0)
    , m_tempBuffer(nullptr)
    , m_instrumentManager(std::make_unique<InstrumentManager>())
    , m_sequenceManager(std::make_unique<SequenceManager>(nullptr, m_instrumentManager.get()))
{
    LOGI("AudioEngine: Constructor called");
    
    // Initialize audio buffers to nullptr
    for (int i = 0; i < BUFFER_COUNT; i++) {
        m_audioBuffers[i] = nullptr;
    }
}

AudioEngine::~AudioEngine() {
    LOGI("AudioEngine: Destructor called");
    
    // Stop the audio engine if it's running
    if (m_isRunning.load()) {
        stop();
    }
    
    // Clean up resources
    cleanup();
}

bool AudioEngine::init(int sampleRate) {
    LOGI("AudioEngine::init(sampleRate=%d)", sampleRate);
    
    try {
        // Set sample rate
        m_sampleRate = sampleRate;
        
        // Initialize OpenSL ES engine
        SLresult result;
        
        // Create engine object
        LOGI("Creating OpenSL ES engine");
        result = slCreateEngine(&m_engineObj, 0, nullptr, 0, nullptr, nullptr);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to create OpenSL ES engine: %d", result);
            return false;
        }
        
        // Realize the engine
        LOGI("Realizing OpenSL ES engine");
        result = (*m_engineObj)->Realize(m_engineObj, SL_BOOLEAN_FALSE);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to realize OpenSL ES engine: %d", result);
            return false;
        }
        
        // Get the engine interface
        LOGI("Getting engine interface");
        result = (*m_engineObj)->GetInterface(m_engineObj, SL_IID_ENGINE, &m_engine);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to get engine interface: %d", result);
            return false;
        }
        
        // Create output mix
        LOGI("Creating output mix");
        result = (*m_engine)->CreateOutputMix(m_engine, &m_outputMixObj, 0, nullptr, nullptr);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to create output mix: %d", result);
            return false;
        }
        
        // Realize the output mix
        LOGI("Realizing output mix");
        result = (*m_outputMixObj)->Realize(m_outputMixObj, SL_BOOLEAN_FALSE);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to realize output mix: %d", result);
            return false;
        }
        
        // Set up audio source
        SLDataLocator_AndroidSimpleBufferQueue loc_bufq = {
            SL_DATALOCATOR_ANDROIDSIMPLEBUFFERQUEUE,
            2  // number of buffers
        };
        
        // PCM format
        SLDataFormat_PCM format_pcm = {
            SL_DATAFORMAT_PCM,
            1,                                // numChannels
            static_cast<SLuint32>(sampleRate * 1000), // Sample rate in milli-Hz
            SL_PCMSAMPLEFORMAT_FIXED_16,      // bitsPerSample
            SL_PCMSAMPLEFORMAT_FIXED_16,      // containerSize
            SL_SPEAKER_FRONT_CENTER,          // channelMask
            SL_BYTEORDER_LITTLEENDIAN         // endianness
        };
        
        SLDataSource audioSrc = {&loc_bufq, &format_pcm};
        
        // Set up audio sink
        SLDataLocator_OutputMix loc_outmix = {SL_DATALOCATOR_OUTPUTMIX, m_outputMixObj};
        SLDataSink audioSnk = {&loc_outmix, nullptr};
        
        // Create audio player
        LOGI("Creating audio player");
        const SLInterfaceID ids[] = {SL_IID_BUFFERQUEUE};
        const SLboolean req[] = {SL_BOOLEAN_TRUE};
        
        result = (*m_engine)->CreateAudioPlayer(m_engine, &m_playerObj, &audioSrc, &audioSnk, 1, ids, req);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to create audio player: %d", result);
            return false;
        }
        
        // Realize the player
        LOGI("Realizing audio player");
        result = (*m_playerObj)->Realize(m_playerObj, SL_BOOLEAN_FALSE);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to realize audio player: %d", result);
            return false;
        }
        
        // Get the play interface
        LOGI("Getting play interface");
        result = (*m_playerObj)->GetInterface(m_playerObj, SL_IID_PLAY, &m_player);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to get play interface: %d", result);
            return false;
        }
        
        // Get the buffer queue interface
        LOGI("Getting buffer queue interface");
        result = (*m_playerObj)->GetInterface(m_playerObj, SL_IID_BUFFERQUEUE, &m_bufferQueue);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to get buffer queue interface: %d", result);
            return false;
        }
        
        // Register callback
        LOGI("Registering buffer queue callback");
        result = (*m_bufferQueue)->RegisterCallback(m_bufferQueue, bufferQueueCallback, this);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to register buffer queue callback: %d", result);
            return false;
        }
        
        // Initialize audio buffers
        LOGI("Initializing audio buffers");
        int bufferSize = BUFFER_SIZE; // Default buffer size
        for (int i = 0; i < BUFFER_COUNT; i++) {
            m_audioBuffers[i] = new short[bufferSize];
            memset(m_audioBuffers[i], 0, bufferSize * sizeof(short));
        }
        
        // Allocate temporary float buffer for audio processing
        m_tempBuffer = new float[bufferSize];
        
        // Set initialized flag
        m_isInitialized = true;
        
        // Initialize the instrument manager
        LOGI("Initializing instrument manager");
        if (!m_instrumentManager) {
            m_instrumentManager = std::make_unique<InstrumentManager>();
        }
        
        // Initialize the sequence manager
        LOGI("Initializing sequence manager");
        if (!m_sequenceManager) {
            m_sequenceManager = std::make_unique<SequenceManager>(nullptr, m_instrumentManager.get());
        }
        
        // Enqueue an empty buffer to start things
        LOGI("Enqueuing initial buffer");
        result = (*m_bufferQueue)->Enqueue(m_bufferQueue, m_audioBuffers[0], bufferSize * sizeof(short));
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to enqueue initial buffer: %d", result);
            return false;
        }
        
        LOGI("AudioEngine initialization successful");
        return true;
    }
    catch (const std::exception& e) {
        LOGE("Exception during initialization: %s", e.what());
        return false;
    }
    catch (...) {
        LOGE("Unknown exception during initialization");
        return false;
    }
}

void AudioEngine::cleanup() {
    LOGI("AudioEngine: Cleaning up resources");
    
    try {
        // Clean up OpenSL ES objects in reverse order of creation
        if (m_playerObj) {
            (*m_playerObj)->Destroy(m_playerObj);
            m_playerObj = nullptr;
            m_player = nullptr;
            m_bufferQueue = nullptr;
            m_playerVolume = nullptr;
        }
        
        if (m_outputMixObj) {
            (*m_outputMixObj)->Destroy(m_outputMixObj);
            m_outputMixObj = nullptr;
        }
        
        if (m_engineObj) {
            (*m_engineObj)->Destroy(m_engineObj);
            m_engineObj = nullptr;
            m_engine = nullptr;
        }
        
        // Free audio buffers
        if (m_buffer1) {
            delete[] m_buffer1;
            m_buffer1 = nullptr;
        }
        
        if (m_buffer2) {
            delete[] m_buffer2;
            m_buffer2 = nullptr;
        }
        
        if (m_floatBuffer) {
            delete[] m_floatBuffer;
            m_floatBuffer = nullptr;
        }
        
        if (m_tempBuffer) {
            delete[] m_tempBuffer;
            m_tempBuffer = nullptr;
        }
        
        if (m_currentBufferPtr) {
            delete[] m_currentBufferPtr;
            m_currentBufferPtr = nullptr;
        }
        
        // Set flags
        m_isInitialized = false;
        m_isRunning.store(false);
        
        LOGI("Audio engine resources cleaned up successfully");
    } catch (const std::exception& e) {
        LOGE("Exception in cleanup: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in cleanup");
    }
}

bool AudioEngine::start() {
    LOGI("AudioEngine::start()");
    
    if (!m_isInitialized) {
        LOGE("Cannot start audio engine: not initialized");
        return false;
    }
    
    if (m_isRunning.load()) {
        LOGI("Audio engine already running");
        return true;
    }
    
    try {
        // Set the play state to playing
        SLresult result = (*m_player)->SetPlayState(m_player, SL_PLAYSTATE_PLAYING);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to set play state to playing: %d", result);
            return false;
        }
        
        // Set running flag
        m_isRunning.store(true);
        LOGI("Audio engine started successfully");
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in start(): %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in start()");
        return false;
    }
}

void AudioEngine::stop() {
    LOGI("AudioEngine::stop()");
    
    if (!m_isRunning.load()) {
        LOGI("Audio engine already stopped");
        return;
    }
    
    try {
        // Set the play state to stopped
        if (m_player) {
            SLresult result = (*m_player)->SetPlayState(m_player, SL_PLAYSTATE_STOPPED);
            if (result != SL_RESULT_SUCCESS) {
                LOGE("Failed to set play state to stopped: %d", result);
            }
        }
        
        // Set running flag to false
        m_isRunning.store(false);
        LOGI("Audio engine stopped successfully");
    } catch (const std::exception& e) {
        LOGE("Exception in stop(): %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in stop()");
    }
}

void AudioEngine::setMasterVolume(float volume) {
    LOGD("Setting master volume to %f", volume);
    
    // Clamp volume to valid range
    volume = std::max(0.0f, std::min(1.0f, volume));
    
    std::lock_guard<std::mutex> lock(m_mutex);
    m_masterVolume = volume;
    
    if (m_playerVolume) {
        // Convert to millibels (SL_MILLIBEL_MIN for silence, 0 for max volume)
        // The range is approximately -96dB (SL_MILLIBEL_MIN) to 0dB
        SLmillibel volumeMB;
        
        if (volume <= 0.0f) {
            volumeMB = SL_MILLIBEL_MIN;
        } else {
            // Convert linear volume to logarithmic scale
            // 0.0 -> SL_MILLIBEL_MIN, 1.0 -> 0
            volumeMB = static_cast<SLmillibel>(2000.0f * std::log10(volume));
            
            // Clamp to valid range
            if (volumeMB < SL_MILLIBEL_MIN) {
                volumeMB = SL_MILLIBEL_MIN;
            }
        }
        
        SLresult result = (*m_playerVolume)->SetVolumeLevel(m_playerVolume, volumeMB);
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to set volume level: %d", result);
        }
    }
}

int AudioEngine::getSampleRate() const {
    return m_sampleRate;
}

float AudioEngine::getMasterVolume() const {
    return m_masterVolume;
}

void AudioEngine::renderAudio(float* buffer, int numFrames) {
    if (!buffer || numFrames <= 0) {
        return;
    }
    
    // Clear buffer
    std::fill(buffer, buffer + numFrames * 2, 0.0f);
    
    // Render audio from instrument manager if available
    if (m_instrumentManager) {
        m_instrumentManager->renderAudio(buffer, numFrames, m_masterVolume);
    }
}

// Audio buffer callback function
void bufferQueueCallback(SLAndroidSimpleBufferQueueItf bq /* unused */, void* context) {
    AudioEngine* engine = static_cast<AudioEngine*>(context);
    if (engine) {
        engine->processNextBuffer();
    }
}

void AudioEngine::processNextBuffer() {
    if (!m_isInitialized) {
        LOGW("Audio engine not initialized in processNextBuffer");
        return;
    }
    
    try {
        // Clear the temporary buffer
        std::memset(m_tempBuffer, 0, m_framesPerBuffer * 2 * sizeof(float));
        
        // Process audio samples
        onProcessSamples(m_tempBuffer, m_framesPerBuffer);
        
        // Make sure current buffer pointer is initialized
        if (!m_currentBufferPtr) {
            m_currentBufferPtr = new int16_t[m_framesPerBuffer * 2];
        }
        
        // Convert float samples to int16_t
        for (int i = 0; i < m_framesPerBuffer * 2; i++) {
            // Clamp to [-1.0, 1.0] and convert to int16_t
            float sample = std::max(-1.0f, std::min(1.0f, m_tempBuffer[i]));
            m_currentBufferPtr[i] = static_cast<int16_t>(sample * 32767.0f);
        }
        
        // Enqueue the buffer
        SLresult result = (*m_bufferQueue)->Enqueue(
            m_bufferQueue,
            m_currentBufferPtr,
            m_framesPerBuffer * 2 * sizeof(int16_t)
        );
        
        if (result != SL_RESULT_SUCCESS) {
            LOGE("Failed to enqueue buffer: %d", result);
        } else {
            LOGD("Buffer enqueued successfully");
        }
    } catch (const std::exception& e) {
        LOGE("Exception in processNextBuffer: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in processNextBuffer");
    }
}

InstrumentManager* AudioEngine::getInstrumentManager() const {
    return m_instrumentManager.get();
}

SequenceManager* AudioEngine::getSequenceManager() const {
    return m_sequenceManager.get();
}

void AudioEngine::onProcessSamples(float* buffer, int numSamples) {
    // Lock the audio mutex to prevent concurrent modifications
    std::lock_guard<std::mutex> lock(m_audioMutex);
    
    // Clear the buffer initially
    std::fill(buffer, buffer + numSamples, 0.0f);
    
    if (!m_instrumentManager) {
        LOGW("No instrument manager available for rendering");
        return;
    }
    
    // Generate sine wave samples for active notes with simple additive synthesis
    try {
        // Get all active instruments and their notes
        auto activeInstruments = m_instrumentManager->getActiveInstruments();
        LOGD("Rendering audio for %zu active instruments", activeInstruments.size());
        
        for (auto instrumentId : activeInstruments) {
            auto activeNotes = m_instrumentManager->getActiveNotes(instrumentId);
            
            if (activeNotes.empty()) {
                continue;
            }
            
            LOGD("Rendering instrument %d with %zu active notes", instrumentId, activeNotes.size());
            
            // Get the instrument settings
            auto instrument = m_instrumentManager->getInstrument(instrumentId);
            if (!instrument.has_value()) {
                continue;
            }
            
            float instrumentVolume = instrument->volume;
            
            // For each active note, generate sine wave and add to buffer
            for (int noteNumber : activeNotes) {
                // Get the velocity (0-127) for this note and normalize to 0.0-1.0
                float velocity = m_instrumentManager->getNoteVelocity(instrumentId, noteNumber) / 127.0f;
                
                // Convert MIDI note to frequency
                // Formula: f = 440 * 2^((n-69)/12) where n is MIDI note number
                float frequency = 440.0f * std::pow(2.0f, (noteNumber - 69.0f) / 12.0f);
                
                // Get the current phase for this note
                float& phase = m_instrumentManager->getNotePhase(instrumentId, noteNumber);
                
                // Generate sine wave samples
                for (int i = 0; i < numSamples; i++) {
                    // Generate sine sample: amplitude * sin(2π * frequency * time)
                    float sample = velocity * instrumentVolume * std::sin(phase);
                    
                    // Add sample to buffer (additive synthesis)
                    buffer[i] += sample * 0.2f; // Scale to avoid clipping
                    
                    // Update phase for next sample
                    // phase += 2π * frequency / sampleRate
                    phase += 2.0f * M_PI * frequency / m_sampleRate;
                    
                    // Wrap phase to stay within 0 to 2π
                    while (phase >= 2.0f * M_PI) {
                        phase -= 2.0f * M_PI;
                    }
                }
                
                LOGD("Generated sine wave for note %d at %.2f Hz", noteNumber, frequency);
            }
        }
    } catch (const std::exception& e) {
        LOGE("Exception in audio processing: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in audio processing");
    }
    
    // Clipping prevention for final output
    for (int i = 0; i < numSamples; i++) {
        // Clamp values to avoid distortion
        buffer[i] = std::max(-1.0f, std::min(1.0f, buffer[i]));
    }
} 