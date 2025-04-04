#ifndef INSTRUMENT_MANAGER_H
#define INSTRUMENT_MANAGER_H

#include <map>
#include <string>
#include <mutex>
#include <set>
#include <optional>
#include <vector>

class AudioEngine;

// Define instrument types
enum class InstrumentType {
    UNDEFINED,
    SINE_WAVE,
    SFZ,
    SF2
};

// Instrument structure
struct Instrument {
    InstrumentType type = InstrumentType::UNDEFINED;
    std::string name;
    std::string filePath;  // For SFZ or SF2 files
    float volume = 1.0f;
    // Additional instrument-specific properties can be added here
};

// Manager class for handling instruments
class InstrumentManager {
public:
    InstrumentManager();
    ~InstrumentManager();
    
    // Set audio engine reference
    void setAudioEngine(AudioEngine* audioEngine);
    
    // Initialize the manager
    bool init();
    
    // Create instruments
    int createSineWaveInstrument(const std::string& name);
    int loadSfzInstrument(const std::string& filePath, const std::string& name);
    int loadSf2Instrument(const std::string& filePath, const std::string& name, int presetIndex);
    bool unloadInstrument(int instrumentId);
    
    // MIDI-style note events
    bool sendNoteOn(int instrumentId, int noteNumber, int velocity);
    bool sendNoteOff(int instrumentId, int noteNumber);
    
    // Stop all notes for an instrument
    bool stopAllNotes(int instrumentId);
    
    // Stop notes for all instruments
    void stopAllNotes();
    
    // Instrument management
    bool setInstrumentVolume(int instrumentId, float volume);
    std::vector<int> getLoadedInstrumentIds();
    
    // Audio rendering
    void renderAudio(float* buffer, int numFrames, float masterVolume);
    
    // Helper methods for audio rendering
    std::vector<int> getActiveInstruments() const;
    std::set<int> getActiveNotes(int instrumentId) const;
    int getNoteVelocity(int instrumentId, int noteNumber) const;
    float& getNotePhase(int instrumentId, int noteNumber);
    std::optional<Instrument> getInstrument(int instrumentId) const;
    
    // Utility functions
    static float midiNoteToFrequency(int note);
    
private:
    // Audio engine reference
    AudioEngine* m_audioEngine = nullptr;
    
    // Initialization state
    bool m_isInitialized = false;
    std::mutex m_mutex;
    
    // Audio parameters
    int m_sampleRate = 44100;
    
    // Maps for instrument management
    std::map<int, Instrument> m_instruments;
    std::map<int, std::set<int>> m_activeNotes;  // instrumentId -> set of active note numbers
    std::map<int, std::map<int, int>> m_noteVelocities;  // instrumentId -> (noteNumber -> velocity)
    std::map<int, std::map<int, float>> m_notePhases;  // instrumentId -> (noteNumber -> phase)
    
    // Generate a unique ID for a new instrument
    int generateUniqueId();
    
    // Constants
    static constexpr int MAX_INSTRUMENTS = 128;
    static constexpr int MAX_NOTES = 128;
    static constexpr int MIN_SAMPLE_RATE = 8000;
    static constexpr int MAX_SAMPLE_RATE = 192000;
};

#endif // INSTRUMENT_MANAGER_H 