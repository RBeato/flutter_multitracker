#ifndef FLUTTER_MULTITRACKER_INSTRUMENT_MANAGER_H
#define FLUTTER_MULTITRACKER_INSTRUMENT_MANAGER_H

#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <set>
#include <vector>

// Forward declarations
class AudioEngine;

// Enum for instrument types
enum class InstrumentType {
    SINE_WAVE,
    UNKNOWN
};

// Struct for instrument data
struct Instrument {
    InstrumentType type = InstrumentType::SINE_WAVE;
    std::string name;
    float volume = 1.0f;
};

class InstrumentManager {
public:
    // Constructor and destructor
    explicit InstrumentManager(AudioEngine* audioEngine);
    ~InstrumentManager();
    
    // Initialization
    bool init(int sampleRate);
    
    // Instrument loading - simplified to just create a sine wave instrument
    int createSineWaveInstrument(const std::string& name);
    bool unloadInstrument(int instrumentId);
    
    // Get an instrument by ID
    Instrument* getInstrument(int instrumentId);
    
    // Note handling
    bool sendNoteOn(int instrumentId, int noteNumber, int velocity);
    bool sendNoteOff(int instrumentId, int noteNumber);
    
    // Volume control
    bool setInstrumentVolume(int instrumentId, float volume);
    
    // Audio rendering
    void renderAudio(float* buffer, int numFrames, float masterVolume);
    
    // Instrument management
    std::vector<int> getLoadedInstrumentIds();
    
private:
    // Audio engine reference
    AudioEngine* m_audioEngine;
    
    // Instrument storage
    std::map<int, Instrument> m_instruments;
    
    // Active notes tracking
    std::map<int, std::set<int>> m_activeNotes;
    
    // Note velocities tracking (instrumentId -> (noteNumber -> velocity))
    std::map<int, std::map<int, int>> m_noteVelocities;
    
    // Note phases tracking for sine wave generation
    std::map<int, std::map<int, float>> m_notePhases;
    
    // Audio configuration
    int m_sampleRate;
    bool m_isInitialized;
    
    // Next instrument ID counter
    int m_nextInstrumentId;
    
    // Thread safety
    mutable std::mutex m_mutex;
    
    // Helper methods
    int generateUniqueId();
    float midiNoteToFrequency(int note);
};

#endif // FLUTTER_MULTITRACKER_INSTRUMENT_MANAGER_H 