#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include <SLES/OpenSLES.h>
#include <SLES/OpenSLES_Android.h>
#include <mutex>
#include <atomic>
#include <memory>

// Forward declarations
class InstrumentManager;
class SequenceManager;

class AudioEngine {
public:
    // Constructor and destructor
    AudioEngine();
    ~AudioEngine();
    
    // Initialize the audio engine
    bool init(int sampleRate);
    
    // Start audio processing
    bool start();
    
    // Stop audio processing
    bool stop();
    
    // Set the master volume (0.0 to 1.0)
    void setMasterVolume(float volume);
    
    // Get the sample rate
    int getSampleRate() const;
    
    // Get the master volume
    float getMasterVolume() const;
    
    // Render audio data
    void renderAudio(float* buffer, int numFrames);
    
    // Getters
    InstrumentManager* getInstrumentManager();
    SequenceManager* getSequenceManager();
    
private:
    // OpenSL ES engine objects
    SLObjectItf m_engineObject;
    SLEngineItf m_engineEngine;
    SLObjectItf m_outputMixObject;
    SLObjectItf m_playerObject;
    SLPlayItf m_playerPlay;
    SLAndroidSimpleBufferQueueItf m_playerBufferQueue;
    SLVolumeItf m_playerVolume;
    
    // Audio configuration
    int m_sampleRate;
    int m_framesPerBuffer;
    float m_masterVolume;
    
    // Audio buffers
    int16_t* m_buffer1;
    int16_t* m_buffer2;
    int16_t* m_currentBuffer;
    float* m_floatBuffer;  // Intermediate buffer for audio processing
    
    // State flags
    std::atomic<bool> m_isPlaying;
    std::atomic<bool> m_isInitialized;
    
    // Mutex for thread safety
    std::mutex m_mutex;
    
    // Callback for buffer queue
    static void bufferQueueCallback(SLAndroidSimpleBufferQueueItf bq, void* context);
    void processBufferQueueCallback();
    
    // Managers
    std::unique_ptr<InstrumentManager> m_instrumentManager;
    std::unique_ptr<SequenceManager> m_sequenceManager;
};

#endif // AUDIO_ENGINE_H 