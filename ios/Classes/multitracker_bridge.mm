#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include "FlutterMultitrackerPlugin-Bridging-Header.h"

// Include C++ headers
#include <memory>
#include <string>
#include <vector>
#include <unordered_map>
#include <mutex>
#include <sfizz.hpp>

// Forward declarations of C++ classes
class AudioEngine;
class InstrumentManager;
class SequenceManager;
class Instrument;
class Sequence;
class Track;

// Global instances
static std::unique_ptr<AudioEngine> audioEngine;

// Audio engine class for iOS
class AudioEngine {
public:
    AudioEngine();
    ~AudioEngine();
    
    bool init(int sampleRate, int framesPerBuffer);
    bool start();
    bool stop();
    
    int getSampleRate() const { return m_sampleRate; }
    void setMasterVolume(float volume);
    
    InstrumentManager* getInstrumentManager() { return m_instrumentManager.get(); }
    SequenceManager* getSequenceManager() { return m_sequenceManager.get(); }
    
private:
    std::unique_ptr<InstrumentManager> m_instrumentManager;
    std::unique_ptr<SequenceManager> m_sequenceManager;
    
    int m_sampleRate;
    int m_framesPerBuffer;
    float m_masterVolume;
    
    AVAudioEngine* m_avAudioEngine;
    AVAudioSourceNode* m_sourceNode;
    std::mutex m_mutex;
    
    // Audio processing callback
    void processBuffer(float* buffer, int frameCount);
};

// Instrument class
class Instrument {
public:
    enum class Type {
        SFZ,
        SF2,
        AUDIOUNIT,
        UNKNOWN
    };
    
    Type type;
    std::string path;
    int preset = 0;
    int bank = 0;
    std::unique_ptr<sfz::Sfizz> sfizz;
    void* audioUnit = nullptr; // AudioUnit or AudioComponentInstance
};

// InstrumentManager class
class InstrumentManager {
public:
    InstrumentManager(AudioEngine* engine);
    ~InstrumentManager();
    
    int loadSFZInstrument(const std::string& path);
    int loadSF2Instrument(const std::string& path, int preset, int bank);
    int loadAudioUnitInstrument(const std::string& componentDescription, const std::string& presetPath);
    bool unloadInstrument(int instrumentId);
    Instrument* getInstrument(int instrumentId);
    void renderAudio(float* buffer, int frameCount, float masterVolume);
    
    // MIDI events
    void sendNoteOn(int instrumentId, int note, int velocity);
    void sendNoteOff(int instrumentId, int note);
    void sendCC(int instrumentId, int cc, int value);
    
private:
    AudioEngine* m_engine;
    std::unordered_map<int, Instrument> m_instruments;
    int m_nextInstrumentId;
    std::mutex m_mutex;
};

// Sequencing classes
struct Note {
    int noteNumber;
    int velocity;
    double startTimeInBeats;
    double durationInBeats;
};

struct AutomationPoint {
    double timeInBeats;
    float value;
};

class Track {
public:
    int id;
    int instrumentId;
    std::vector<Note> notes;
    std::vector<AutomationPoint> volumeAutomation;
    float volume;
};

class Sequence {
public:
    int id;
    double tempo;
    double lengthInBeats;
    bool isLooping;
    std::unordered_map<int, Track> tracks;
};

// SequenceManager class
class SequenceManager {
public:
    SequenceManager(AudioEngine* engine, InstrumentManager* instrumentManager);
    ~SequenceManager();
    
    int createSequence(double tempo, double lengthInBeats);
    bool deleteSequence(int sequenceId);
    Sequence* getSequence(int sequenceId);
    
    int addTrack(int sequenceId, int instrumentId);
    bool deleteTrack(int sequenceId, int trackId);
    
    int addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startTime, double duration);
    bool deleteNote(int sequenceId, int trackId, int noteId);
    
    int addVolumeAutomation(int sequenceId, int trackId, double timeInBeats, float volume);
    bool deleteVolumeAutomation(int sequenceId, int trackId, int automationId);
    void setTrackVolume(int sequenceId, int trackId, float volume);
    
    void startPlayback(int sequenceId);
    void stopPlayback();
    void setPlaybackPosition(double positionInBeats);
    double getPlaybackPosition() const;
    
    void setTempo(int sequenceId, double tempo);
    void setLooping(int sequenceId, bool isLooping);
    
    void processAudio(double sampleRate, double bufferSize);
    
private:
    AudioEngine* m_engine;
    InstrumentManager* m_instrumentManager;
    std::unordered_map<int, Sequence> m_sequences;
    
    int m_nextSequenceId;
    int m_nextTrackId;
    
    int m_activeSequenceId;
    double m_currentPositionInBeats;
    double m_lastProcessTimeMs;
    bool m_isPlaying;
    
    std::mutex m_mutex;
    
    // Helper methods
    float getTrackVolumeAtPosition(const Track& track, double positionInBeats);
    void processActiveNotes(double positionInBeats, double previousPositionInBeats, double sampleRate);
};

// C++ implementation of the AudioEngine for iOS

AudioEngine::AudioEngine()
    : m_sampleRate(0),
      m_framesPerBuffer(0),
      m_masterVolume(1.0f),
      m_avAudioEngine(nil) {
    NSLog(@"AudioEngine created");
}

AudioEngine::~AudioEngine() {
    stop();
    NSLog(@"AudioEngine destroyed");
}

bool AudioEngine::init(int sampleRate, int framesPerBuffer) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    m_sampleRate = sampleRate;
    m_framesPerBuffer = framesPerBuffer;
    
    // Create managers
    m_instrumentManager = std::make_unique<InstrumentManager>(this);
    m_sequenceManager = std::make_unique<SequenceManager>(this, m_instrumentManager.get());
    
    // Create AVAudioEngine
    m_avAudioEngine = [[AVAudioEngine alloc] init];
    
    // Configure source node
    AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:2];
    
    // Create source node with render block
    m_sourceNode = [[AVAudioSourceNode alloc] initWithRenderBlock:^OSStatus(BOOL *isSilence, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, AudioBufferList *outputData) {
        // Get buffer for processing
        float* buffer = (float*)outputData->mBuffers[0].mData;
        int channelCount = outputData->mNumberBuffers;
        int totalFrames = frameCount * channelCount;
        
        // Clear buffer
        memset(buffer, 0, totalFrames * sizeof(float));
        
        // Process audio
        self->processBuffer(buffer, frameCount);
        
        *isSilence = NO;
        return noErr;
    }];
    
    // Connect nodes
    [m_avAudioEngine attachNode:m_sourceNode];
    [m_avAudioEngine connect:m_sourceNode to:m_avAudioEngine.mainMixerNode format:format];
    
    // Set output volume
    m_avAudioEngine.mainMixerNode.outputVolume = m_masterVolume;
    
    NSLog(@"AudioEngine initialized with sample rate %d, frames per buffer %d", sampleRate, framesPerBuffer);
    return true;
}

bool AudioEngine::start() {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    NSError* error = nil;
    if (![m_avAudioEngine startAndReturnError:&error]) {
        NSLog(@"Failed to start AVAudioEngine: %@", error);
        return false;
    }
    
    NSLog(@"AudioEngine started");
    return true;
}

bool AudioEngine::stop() {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    if (m_avAudioEngine) {
        [m_avAudioEngine stop];
        NSLog(@"AudioEngine stopped");
    }
    
    return true;
}

void AudioEngine::setMasterVolume(float volume) {
    m_masterVolume = volume;
    
    if (m_avAudioEngine) {
        m_avAudioEngine.mainMixerNode.outputVolume = volume;
    }
}

void AudioEngine::processBuffer(float* buffer, int frameCount) {
    // Process sequences
    m_sequenceManager->processAudio(m_sampleRate, frameCount);
    
    // Render audio from all instruments into the buffer
    m_instrumentManager->renderAudio(buffer, frameCount, m_masterVolume);
}

// Minimal implementations of the management classes

// InstrumentManager implementation
InstrumentManager::InstrumentManager(AudioEngine* engine)
    : m_engine(engine),
      m_nextInstrumentId(1) {
    NSLog(@"InstrumentManager created");
}

InstrumentManager::~InstrumentManager() {
    NSLog(@"InstrumentManager destroyed");
}

int InstrumentManager::loadSFZInstrument(const std::string& path) {
    std::lock_guard<std::mutex> lock(m_mutex);
    NSLog(@"Loading SFZ instrument from %s", path.c_str());
    
    // Create instrument
    int instrumentId = m_nextInstrumentId++;
    auto& instrument = m_instruments[instrumentId];
    
    instrument.type = Instrument::Type::SFZ;
    instrument.path = path;
    instrument.sfizz = std::make_unique<sfz::Sfizz>();
    
    // Set sfizz options
    int sampleRate = m_engine->getSampleRate();
    instrument.sfizz->setSamplesPerBlock(4096); // Use a reasonably large buffer
    instrument.sfizz->setSampleRate(sampleRate);
    
    // Load the SFZ file
    bool success = instrument.sfizz->loadSfzFile(path);
    
    if (!success) {
        NSLog(@"Failed to load SFZ file: %s", path.c_str());
        m_instruments.erase(instrumentId);
        return -1;
    }
    
    NSLog(@"Successfully loaded SFZ instrument with ID %d", instrumentId);
    return instrumentId;
}

int InstrumentManager::loadSF2Instrument(const std::string& path, int preset, int bank) {
    // Not implemented yet
    NSLog(@"SF2 instrument loading not implemented yet");
    return -1;
}

int InstrumentManager::loadAudioUnitInstrument(const std::string& componentDescription, const std::string& presetPath) {
    // Not implemented yet
    NSLog(@"AudioUnit instrument loading not implemented yet");
    return -1;
}

bool InstrumentManager::unloadInstrument(int instrumentId) {
    std::lock_guard<std::mutex> lock(m_mutex);
    NSLog(@"Unloading instrument with ID %d", instrumentId);
    
    auto it = m_instruments.find(instrumentId);
    if (it == m_instruments.end()) {
        NSLog(@"Instrument with ID %d not found", instrumentId);
        return false;
    }
    
    m_instruments.erase(it);
    NSLog(@"Instrument with ID %d unloaded", instrumentId);
    return true;
}

Instrument* InstrumentManager::getInstrument(int instrumentId) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    auto it = m_instruments.find(instrumentId);
    if (it == m_instruments.end()) {
        return nullptr;
    }
    
    return &it->second;
}

void InstrumentManager::renderAudio(float* buffer, int frameCount, float masterVolume) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    // Temporary buffer for mixing
    std::vector<float> tempBuffer(frameCount * 2);
    
    for (auto& pair : m_instruments) {
        auto& instrument = pair.second;
        
        if (instrument.sfizz) {
            // Clear temp buffer
            std::fill(tempBuffer.begin(), tempBuffer.end(), 0.0f);
            
            // Render audio from this instrument
            instrument.sfizz->renderBlock(tempBuffer.data(), frameCount);
            
            // Mix into main buffer
            for (int i = 0; i < frameCount * 2; i++) {
                buffer[i] += tempBuffer[i] * masterVolume;
            }
        }
    }
}

void InstrumentManager::sendNoteOn(int instrumentId, int note, int velocity) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    auto it = m_instruments.find(instrumentId);
    if (it != m_instruments.end() && it->second.sfizz) {
        it->second.sfizz->noteOn(0, note, velocity);
    }
}

void InstrumentManager::sendNoteOff(int instrumentId, int note) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    auto it = m_instruments.find(instrumentId);
    if (it != m_instruments.end() && it->second.sfizz) {
        it->second.sfizz->noteOff(0, note, 0);
    }
}

void InstrumentManager::sendCC(int instrumentId, int cc, int value) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    auto it = m_instruments.find(instrumentId);
    if (it != m_instruments.end() && it->second.sfizz) {
        it->second.sfizz->cc(0, cc, value);
    }
}

// SequenceManager implementation
SequenceManager::SequenceManager(AudioEngine* engine, InstrumentManager* instrumentManager)
    : m_engine(engine),
      m_instrumentManager(instrumentManager),
      m_nextSequenceId(1),
      m_nextTrackId(1),
      m_activeSequenceId(-1),
      m_currentPositionInBeats(0.0),
      m_lastProcessTimeMs(0.0),
      m_isPlaying(false) {
    NSLog(@"SequenceManager created");
}

SequenceManager::~SequenceManager() {
    NSLog(@"SequenceManager destroyed");
}

int SequenceManager::createSequence(double tempo, double lengthInBeats) {
    std::lock_guard<std::mutex> lock(m_mutex);
    NSLog(@"Creating sequence with tempo %f, length %f beats", tempo, lengthInBeats);
    
    int sequenceId = m_nextSequenceId++;
    auto& sequence = m_sequences[sequenceId];
    
    sequence.id = sequenceId;
    sequence.tempo = tempo;
    sequence.lengthInBeats = lengthInBeats;
    sequence.isLooping = false;
    
    NSLog(@"Created sequence with ID %d", sequenceId);
    return sequenceId;
}

bool SequenceManager::deleteSequence(int sequenceId) {
    std::lock_guard<std::mutex> lock(m_mutex);
    NSLog(@"Deleting sequence with ID %d", sequenceId);
    
    auto it = m_sequences.find(sequenceId);
    if (it == m_sequences.end()) {
        NSLog(@"Sequence with ID %d not found", sequenceId);
        return false;
    }
    
    if (m_activeSequenceId == sequenceId && m_isPlaying) {
        stopPlayback();
    }
    
    m_sequences.erase(it);
    NSLog(@"Deleted sequence with ID %d", sequenceId);
    return true;
}

Sequence* SequenceManager::getSequence(int sequenceId) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    auto it = m_sequences.find(sequenceId);
    if (it == m_sequences.end()) {
        return nullptr;
    }
    
    return &it->second;
}

int SequenceManager::addTrack(int sequenceId, int instrumentId) {
    std::lock_guard<std::mutex> lock(m_mutex);
    NSLog(@"Adding track with instrument %d to sequence %d", instrumentId, sequenceId);
    
    auto sequenceIt = m_sequences.find(sequenceId);
    if (sequenceIt == m_sequences.end()) {
        NSLog(@"Sequence with ID %d not found", sequenceId);
        return -1;
    }
    
    // Check if instrument exists
    if (m_instrumentManager->getInstrument(instrumentId) == nullptr) {
        NSLog(@"Instrument with ID %d not found", instrumentId);
        return -1;
    }
    
    int trackId = m_nextTrackId++;
    auto& track = sequenceIt->second.tracks[trackId];
    
    track.id = trackId;
    track.instrumentId = instrumentId;
    track.volume = 1.0f;
    
    NSLog(@"Added track with ID %d to sequence %d", trackId, sequenceId);
    return trackId;
}

// C function implementations for bridging

bool initAudioEngine(int sampleRate, int framesPerBuffer) {
    if (!audioEngine) {
        audioEngine = std::make_unique<AudioEngine>();
    }
    return audioEngine->init(sampleRate, framesPerBuffer);
}

bool startAudioEngine() {
    if (!audioEngine) {
        return false;
    }
    return audioEngine->start();
}

bool stopAudioEngine() {
    if (!audioEngine) {
        return false;
    }
    return audioEngine->stop();
}

bool setMasterVolume(float volume) {
    if (!audioEngine) {
        return false;
    }
    audioEngine->setMasterVolume(volume);
    return true;
}

int loadSFZInstrument(const char* sfzPath) {
    if (!audioEngine) {
        return -1;
    }
    return audioEngine->getInstrumentManager()->loadSFZInstrument(sfzPath);
}

int loadSF2Instrument(const char* sf2Path, int preset, int bank) {
    if (!audioEngine) {
        return -1;
    }
    return audioEngine->getInstrumentManager()->loadSF2Instrument(sf2Path, preset, bank);
}

int loadAudioUnitInstrument(const char* componentDescription, const char* auPresetPath) {
    if (!audioEngine) {
        return -1;
    }
    return audioEngine->getInstrumentManager()->loadAudioUnitInstrument(componentDescription, auPresetPath ? auPresetPath : "");
}

bool unloadInstrument(int instrumentId) {
    if (!audioEngine) {
        return false;
    }
    return audioEngine->getInstrumentManager()->unloadInstrument(instrumentId);
}

int createSequence(double tempo, double lengthInBeats) {
    if (!audioEngine) {
        return -1;
    }
    return audioEngine->getSequenceManager()->createSequence(tempo, lengthInBeats);
}

bool deleteSequence(int sequenceId) {
    if (!audioEngine) {
        return false;
    }
    return audioEngine->getSequenceManager()->deleteSequence(sequenceId);
}

int addTrack(int sequenceId, int instrumentId) {
    if (!audioEngine) {
        return -1;
    }
    return audioEngine->getSequenceManager()->addTrack(sequenceId, instrumentId);
}

bool deleteTrack(int sequenceId, int trackId) {
    if (!audioEngine) {
        return false;
    }
    return audioEngine->getSequenceManager()->deleteTrack(sequenceId, trackId);
}

int addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startTime, double duration) {
    if (!audioEngine) {
        return -1;
    }
    return audioEngine->getSequenceManager()->addNote(sequenceId, trackId, noteNumber, velocity, startTime, duration);
}

bool deleteNote(int sequenceId, int trackId, int noteId) {
    if (!audioEngine) {
        return false;
    }
    return audioEngine->getSequenceManager()->deleteNote(sequenceId, trackId, noteId);
}

int addVolumeAutomation(int sequenceId, int trackId, double time, float volume) {
    if (!audioEngine) {
        return -1;
    }
    return audioEngine->getSequenceManager()->addVolumeAutomation(sequenceId, trackId, time, volume);
}

bool deleteVolumeAutomation(int sequenceId, int trackId, int automationId) {
    if (!audioEngine) {
        return false;
    }
    return audioEngine->getSequenceManager()->deleteVolumeAutomation(sequenceId, trackId, automationId);
}

bool setTrackVolume(int sequenceId, int trackId, float volume) {
    if (!audioEngine) {
        return false;
    }
    audioEngine->getSequenceManager()->setTrackVolume(sequenceId, trackId, volume);
    return true;
}

bool startPlayback(int sequenceId) {
    if (!audioEngine) {
        return false;
    }
    audioEngine->getSequenceManager()->startPlayback(sequenceId);
    return true;
}

bool stopPlayback() {
    if (!audioEngine) {
        return false;
    }
    audioEngine->getSequenceManager()->stopPlayback();
    return true;
}

bool setPlaybackPosition(double positionInBeats) {
    if (!audioEngine) {
        return false;
    }
    audioEngine->getSequenceManager()->setPlaybackPosition(positionInBeats);
    return true;
}

double getPlaybackPosition() {
    if (!audioEngine) {
        return 0.0;
    }
    return audioEngine->getSequenceManager()->getPlaybackPosition();
}

bool setTempo(int sequenceId, double tempo) {
    if (!audioEngine) {
        return false;
    }
    audioEngine->getSequenceManager()->setTempo(sequenceId, tempo);
    return true;
}

bool setLooping(int sequenceId, bool isLooping) {
    if (!audioEngine) {
        return false;
    }
    audioEngine->getSequenceManager()->setLooping(sequenceId, isLooping);
    return true;
} 