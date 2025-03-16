#include "audio_engine.h"
#include "instrument_manager.h"
#include "sequence_manager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>
#include <cstring>

#define LOG_TAG "AudioEngine"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Default buffer size (2 channels * frames)
#define DEFAULT_FRAMES_PER_BUFFER 512

AudioEngine::AudioEngine()
    : m_engineObject(nullptr),
      m_engineEngine(nullptr),
      m_outputMixObject(nullptr),
      m_playerObject(nullptr),
      m_playerPlay(nullptr),
      m_playerBufferQueue(nullptr),
      m_playerVolume(nullptr),
      m_sampleRate(0),
      m_framesPerBuffer(DEFAULT_FRAMES_PER_BUFFER),
      m_masterVolume(1.0f),
      m_buffer1(nullptr),
      m_buffer2(nullptr),
      m_currentBuffer(nullptr),
      m_floatBuffer(nullptr),
      m_isPlaying(false),
      m_isInitialized(false) {
    LOGD("AudioEngine constructor");
}

AudioEngine::~AudioEngine() {
    LOGD("AudioEngine destructor");
    
    // Stop playback if active
    if (m_isPlaying) {
        stop();
    }
    
    // Clean up buffers
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
    
    // Clean up OpenSL ES objects
    if (m_playerObject) {
        (*m_playerObject)->Destroy(m_playerObject);
        m_playerObject = nullptr;
        m_playerPlay = nullptr;
        m_playerBufferQueue = nullptr;
        m_playerVolume = nullptr;
    }
    
    if (m_outputMixObject) {
        (*m_outputMixObject)->Destroy(m_outputMixObject);
        m_outputMixObject = nullptr;
    }
    
    if (m_engineObject) {
        (*m_engineObject)->Destroy(m_engineObject);
        m_engineObject = nullptr;
        m_engineEngine = nullptr;
    }
    
    LOGD("AudioEngine destroyed");
}

bool AudioEngine::init(int sampleRate) {
    LOGD("Initializing AudioEngine with sample rate: %d", sampleRate);
    
    std::lock_guard<std::mutex> lock(m_mutex);
    
    if (m_isInitialized) {
        LOGW("AudioEngine already initialized");
        return true;
    }
    
    // Validate sample rate
    if (sampleRate <= 0) {
        LOGE("Invalid sample rate: %d", sampleRate);
        return false;
    }
    
    m_sampleRate = sampleRate;
    
    // Create audio buffers
    const int bufferSize = m_framesPerBuffer * 2; // Stereo
    m_buffer1 = new int16_t[bufferSize]();
    m_buffer2 = new int16_t[bufferSize]();
    m_floatBuffer = new float[bufferSize]();
    m_currentBuffer = m_buffer1;
    
    // Create OpenSL ES engine
    SLresult result = slCreateEngine(&m_engineObject, 0, nullptr, 0, nullptr, nullptr);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to create OpenSL ES engine: %d", result);
        return false;
    }
    
    // Realize the engine
    result = (*m_engineObject)->Realize(m_engineObject, SL_BOOLEAN_FALSE);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to realize OpenSL ES engine: %d", result);
        return false;
    }
    
    // Get the engine interface
    result = (*m_engineObject)->GetInterface(m_engineObject, SL_IID_ENGINE, &m_engineEngine);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to get OpenSL ES engine interface: %d", result);
        return false;
    }
    
    // Create output mix
    result = (*m_engineEngine)->CreateOutputMix(m_engineEngine, &m_outputMixObject, 0, nullptr, nullptr);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to create OpenSL ES output mix: %d", result);
        return false;
    }
    
    // Realize the output mix
    result = (*m_outputMixObject)->Realize(m_outputMixObject, SL_BOOLEAN_FALSE);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to realize OpenSL ES output mix: %d", result);
        return false;
    }
    
    // Configure audio source
    SLDataLocator_AndroidSimpleBufferQueue loc_bufq = {
        SL_DATALOCATOR_ANDROIDSIMPLEBUFFERQUEUE,
        2  // Number of buffers
    };
    
    // PCM format
    SLDataFormat_PCM format_pcm = {
        SL_DATAFORMAT_PCM,
        2,                          // 2 channels (stereo)
        static_cast<SLuint32>(sampleRate * 1000),  // Sample rate in milliHz
        SL_PCMSAMPLEFORMAT_FIXED_16,  // 16-bit samples (more widely supported)
        SL_PCMSAMPLEFORMAT_FIXED_16,  // Same container size as sample size
        SL_SPEAKER_FRONT_LEFT | SL_SPEAKER_FRONT_RIGHT,  // Channel mask
        SL_BYTEORDER_LITTLEENDIAN  // Byte order
    };
    
    SLDataSource audioSrc = {&loc_bufq, &format_pcm};
    
    // Configure audio sink
    SLDataLocator_OutputMix loc_outmix = {
        SL_DATALOCATOR_OUTPUTMIX,
        m_outputMixObject
    };
    
    SLDataSink audioSnk = {&loc_outmix, nullptr};
    
    // Create audio player
    const SLInterfaceID ids[] = {SL_IID_ANDROIDSIMPLEBUFFERQUEUE, SL_IID_VOLUME};
    const SLboolean req[] = {SL_BOOLEAN_TRUE, SL_BOOLEAN_TRUE};
    
    result = (*m_engineEngine)->CreateAudioPlayer(
        m_engineEngine,
        &m_playerObject,
        &audioSrc,
        &audioSnk,
        2,  // Number of interfaces
        ids,
        req
    );
    
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to create OpenSL ES audio player: %d", result);
        return false;
    }
    
    // Realize the player
    result = (*m_playerObject)->Realize(m_playerObject, SL_BOOLEAN_FALSE);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to realize OpenSL ES audio player: %d", result);
        return false;
    }
    
    // Get the play interface
    result = (*m_playerObject)->GetInterface(m_playerObject, SL_IID_PLAY, &m_playerPlay);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to get OpenSL ES play interface: %d", result);
        return false;
    }
    
    // Get the buffer queue interface
    result = (*m_playerObject)->GetInterface(m_playerObject, SL_IID_ANDROIDSIMPLEBUFFERQUEUE, &m_playerBufferQueue);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to get OpenSL ES buffer queue interface: %d", result);
        return false;
    }
    
    // Get the volume interface
    result = (*m_playerObject)->GetInterface(m_playerObject, SL_IID_VOLUME, &m_playerVolume);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to get OpenSL ES volume interface: %d", result);
        return false;
    }
    
    // Register callback
    result = (*m_playerBufferQueue)->RegisterCallback(
        m_playerBufferQueue,
        AudioEngine::bufferQueueCallback,
        this
    );
    
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to register OpenSL ES buffer queue callback: %d", result);
        return false;
    }
    
    // Set initial volume
    setMasterVolume(m_masterVolume);
    
    // Create the instrument manager
    LOGI("Creating instrument manager within AudioEngine");
    m_instrumentManager = std::make_unique<InstrumentManager>(this);
    if (!m_instrumentManager) {
        LOGE("Failed to create instrument manager");
        return false;
    }
    
    // Initialize the instrument manager
    if (!m_instrumentManager->init(sampleRate)) {
        LOGE("Failed to initialize instrument manager");
        m_instrumentManager.reset();
        return false;
    }
    
    // Create the sequence manager
    LOGI("Creating sequence manager within AudioEngine");
    m_sequenceManager = std::make_unique<SequenceManager>(m_instrumentManager.get());
    if (!m_sequenceManager) {
        LOGE("Failed to create sequence manager");
        m_instrumentManager.reset();
        return false;
    }
    
    // Initialize the sequence manager
    if (!m_sequenceManager->init()) {
        LOGE("Failed to initialize sequence manager");
        m_sequenceManager.reset();
        m_instrumentManager.reset();
        return false;
    }
    
    m_isInitialized = true;
    LOGI("AudioEngine initialized successfully");
    
    return true;
}

bool AudioEngine::start() {
    LOGD("Starting AudioEngine");
    
    std::lock_guard<std::mutex> lock(m_mutex);
    
    if (!m_isInitialized) {
        LOGE("AudioEngine not initialized");
        return false;
    }
    
    if (m_isPlaying) {
        LOGW("AudioEngine already started");
        return true;
    }
    
    // Clear buffers
    const int bufferSize = m_framesPerBuffer * 2; // Stereo
    std::memset(m_buffer1, 0, bufferSize * sizeof(int16_t));
    std::memset(m_buffer2, 0, bufferSize * sizeof(int16_t));
    
    // Enqueue initial buffer
    SLresult result = (*m_playerBufferQueue)->Enqueue(
        m_playerBufferQueue,
        m_buffer1,
        bufferSize * sizeof(int16_t)
    );
    
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to enqueue initial buffer: %d", result);
        return false;
    }
    
    // Start playback
    result = (*m_playerPlay)->SetPlayState(m_playerPlay, SL_PLAYSTATE_PLAYING);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to start playback: %d", result);
        return false;
    }
    
    m_isPlaying = true;
    LOGI("AudioEngine started successfully");
    
    return true;
}

bool AudioEngine::stop() {
    LOGD("Stopping AudioEngine");
    
    std::lock_guard<std::mutex> lock(m_mutex);
    
    if (!m_isInitialized) {
        LOGE("AudioEngine not initialized");
        return false;
    }
    
    if (!m_isPlaying) {
        LOGW("AudioEngine already stopped");
        return true;
    }
    
    // Stop playback
    SLresult result = (*m_playerPlay)->SetPlayState(m_playerPlay, SL_PLAYSTATE_STOPPED);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to stop playback: %d", result);
        return false;
    }
    
    // Clear buffer queue
    result = (*m_playerBufferQueue)->Clear(m_playerBufferQueue);
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to clear buffer queue: %d", result);
        // Continue anyway
    }
    
    m_isPlaying = false;
    LOGI("AudioEngine stopped successfully");
    
    return true;
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

void AudioEngine::bufferQueueCallback(SLAndroidSimpleBufferQueueItf bq, void* context) {
    AudioEngine* engine = static_cast<AudioEngine*>(context);
    if (engine) {
        engine->processBufferQueueCallback();
    }
}

void AudioEngine::processBufferQueueCallback() {
    if (!m_isPlaying) {
        return;
    }
    
    // Swap buffers
    int16_t* buffer = (m_currentBuffer == m_buffer1) ? m_buffer2 : m_buffer1;
    m_currentBuffer = buffer;
    
    // Clear float buffer
    std::fill(m_floatBuffer, m_floatBuffer + m_framesPerBuffer * 2, 0.0f);
    
    // Render audio to float buffer
    renderAudio(m_floatBuffer, m_framesPerBuffer);
    
    // Convert float to int16_t
    for (int i = 0; i < m_framesPerBuffer * 2; i++) {
        // Clamp to [-1.0, 1.0] and convert to int16_t
        float sample = std::max(-1.0f, std::min(1.0f, m_floatBuffer[i]));
        buffer[i] = static_cast<int16_t>(sample * 32767.0f);
    }
    
    // Enqueue the buffer
    SLresult result = (*m_playerBufferQueue)->Enqueue(
        m_playerBufferQueue,
        buffer,
        m_framesPerBuffer * 2 * sizeof(int16_t)
    );
    
    if (result != SL_RESULT_SUCCESS) {
        LOGE("Failed to enqueue buffer: %d", result);
    }
}

InstrumentManager* AudioEngine::getInstrumentManager() {
    return m_instrumentManager.get();
}

SequenceManager* AudioEngine::getSequenceManager() {
    return m_sequenceManager.get();
} 