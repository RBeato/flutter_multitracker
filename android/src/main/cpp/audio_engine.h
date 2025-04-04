#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include <thread>
#include <atomic>
#include <memory>
#include <SLES/OpenSLES.h>
#include <SLES/OpenSLES_Android.h>
#include "instrument_manager.h"
#include "sequence_manager.h"

class AudioEngine {
public:
    AudioEngine();
    ~AudioEngine();
    
    // Initialize the audio engine
    bool init(int sampleRate);
    
    // Start the audio engine
    bool start();
    
    // Stop the audio engine
    void stop();
    
    // Audio processing
    void processNextBuffer();
    void onProcessSamples(float* buffer, int numSamples);
    void renderAudio(float* buffer, int numFrames);
    
    // Getters
    int getSampleRate() const;
    InstrumentManager* getInstrumentManager() const;
    SequenceManager* getSequenceManager() const;
    
    // Volume control
    void setMasterVolume(float volume);
    float getMasterVolume() const;
    
    // Is audio engine running?
    bool isRunning() const { return m_isRunning.load(); }
    
private:
    // Initialization state
    bool m_isInitialized = false;
    std::atomic<bool> m_isRunning{false};
    
    // Audio parameters
    int m_sampleRate = 44100;
    int m_framesPerBuffer = 1024;
    static const int BUFFER_SIZE = 1024;
    static const int BUFFER_COUNT = 2;
    
    // Master volume
    float m_masterVolume = 1.0f;
    
    // Audio thread synchronization
    std::mutex m_audioMutex;
    std::mutex m_mutex;
    
    // OpenSL ES objects
    SLObjectItf m_engineObj = nullptr;
    SLEngineItf m_engine = nullptr;
    SLObjectItf m_outputMixObj = nullptr;
    SLObjectItf m_playerObj = nullptr;
    SLPlayItf m_player = nullptr;
    SLAndroidSimpleBufferQueueItf m_bufferQueue = nullptr;
    SLVolumeItf m_playerVolume = nullptr;
    
    // Audio buffers
    short* m_audioBuffers[BUFFER_COUNT] = {nullptr};
    int m_currentBuffer = 0;  // Index of current buffer
    float* m_tempBuffer = nullptr;
    short* m_buffer1 = nullptr;
    short* m_buffer2 = nullptr;
    float* m_floatBuffer = nullptr;
    int16_t* m_currentBufferPtr = nullptr;  // Pointer to current buffer data
    
    // Managers
    std::unique_ptr<InstrumentManager> m_instrumentManager;
    std::unique_ptr<SequenceManager> m_sequenceManager;
    
    // Cleanup resources
    void cleanup();
};

#endif // AUDIO_ENGINE_H 