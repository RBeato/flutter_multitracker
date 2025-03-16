#include "instrument_manager.h"
#include "audio_engine.h"
#include <android/log.h>
#include <vector>
#include <string>
#include <stdexcept>
#include <algorithm>
#include <cmath>

// Define M_PI if not already defined
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Logging macros
#define LOG_TAG "InstrumentManager"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Constants for safety
#define MAX_INSTRUMENTS 32
#define MAX_NOTES 128
#define MIN_SAMPLE_RATE 8000
#define MAX_SAMPLE_RATE 192000

// Constructor
InstrumentManager::InstrumentManager(AudioEngine* audioEngine)
    : m_audioEngine(audioEngine),
      m_sampleRate(44100),
      m_isInitialized(false),
      m_nextInstrumentId(1) {
    LOGI("InstrumentManager created");
    m_instruments.clear();
    m_activeNotes.clear();
    m_noteVelocities.clear();
    m_notePhases.clear();
}

// Destructor
InstrumentManager::~InstrumentManager() {
    LOGD("InstrumentManager destructor called");
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_instruments.clear();
        m_activeNotes.clear();
        m_noteVelocities.clear();
        m_notePhases.clear();
        LOGD("InstrumentManager destroyed successfully");
    } catch (const std::exception& e) {
        LOGE("Exception in destructor: %s", e.what());
    }
}

bool InstrumentManager::init(int sampleRate) {
    LOGD("Initializing InstrumentManager with sample rate: %d", sampleRate);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Validate sample rate
        if (sampleRate < MIN_SAMPLE_RATE || sampleRate > MAX_SAMPLE_RATE) {
            LOGE("Invalid sample rate: %d, using default 44100", sampleRate);
            m_sampleRate = 44100;
        } else {
            m_sampleRate = sampleRate;
        }
        
        // Get the sample rate from the audio engine as a fallback
        if (m_audioEngine && m_sampleRate == 0) {
            m_sampleRate = m_audioEngine->getSampleRate();
            LOGD("Using audio engine sample rate: %d", m_sampleRate);
        }
        
        // Clear any existing instruments and active notes
        m_instruments.clear();
        m_activeNotes.clear();
        m_noteVelocities.clear();
        m_notePhases.clear();
        
        m_isInitialized = true;
        LOGD("InstrumentManager initialized successfully");
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in init: %s", e.what());
        m_isInitialized = false;
        return false;
    }
}

// Create a sine wave instrument
int InstrumentManager::createSineWaveInstrument(const std::string& name) {
    LOGI("Creating sine wave instrument: %s", name.c_str());
    try {
        if (!m_isInitialized) {
            LOGE("InstrumentManager not initialized");
            return -1;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if we've reached the maximum number of instruments
        if (m_instruments.size() >= MAX_INSTRUMENTS) {
            LOGE("Maximum number of instruments reached (%d)", MAX_INSTRUMENTS);
            return -1;
        }
        
        // Create instrument
        int instrumentId = m_nextInstrumentId++;
        auto& instrument = m_instruments[instrumentId];
        
        instrument.type = InstrumentType::SINE_WAVE;
        instrument.name = name;
        instrument.volume = 1.0f;
        
        LOGI("Successfully created sine wave instrument '%s' with ID: %d", 
             name.c_str(), instrumentId);
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
bool InstrumentManager::unloadInstrument(int instrumentId) {
    LOGD("Unloading instrument with ID: %d", instrumentId);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        auto it = m_instruments.find(instrumentId);
        if (it == m_instruments.end()) {
            LOGW("Instrument with ID %d not found", instrumentId);
            return false;
        }
        
        // First, clear all active notes for this instrument
        m_activeNotes.erase(instrumentId);
        m_noteVelocities.erase(instrumentId);
        m_notePhases.erase(instrumentId);
        
        // Then remove the instrument
        m_instruments.erase(it);
        LOGD("Successfully unloaded instrument with ID: %d", instrumentId);
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in unloadInstrument: %s", e.what());
        return false;
    }
}

// Get an instrument by ID
Instrument* InstrumentManager::getInstrument(int instrumentId) {
    std::lock_guard<std::mutex> lock(m_mutex);
    
    auto it = m_instruments.find(instrumentId);
    if (it == m_instruments.end()) {
        return nullptr;
    }
    
    return &it->second;
}

// Convert MIDI note number to frequency
float InstrumentManager::midiNoteToFrequency(int note) {
    // A4 = 69 = 440Hz
    return 440.0f * std::pow(2.0f, (note - 69) / 12.0f);
}

// Render audio for all instruments
void InstrumentManager::renderAudio(float* buffer, int numFrames, float masterVolume) {
    try {
        if (!m_isInitialized || !buffer) {
            // Skip processing if not initialized or buffer is null
            if (!buffer) LOGE("Null buffer passed to renderAudio");
            if (!m_isInitialized) LOGE("InstrumentManager not initialized");
            return;
        }
        
        // Safely cap numFrames to a reasonable range
        numFrames = std::max(1, std::min(numFrames, 4096));
        
        // Clear the buffer first
        for (int i = 0; i < numFrames * 2; i++) {
            buffer[i] = 0.0f;
        }
        
        // Only process if we have instruments loaded
        if (m_instruments.empty()) {
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if we have active notes
        bool hasActiveNotes = false;
        
        // Process each instrument with active notes
        for (const auto& [instrumentId, notes] : m_activeNotes) {
            if (notes.empty()) {
                continue;
            }
            
            hasActiveNotes = true;
            
            // Get the instrument
            auto instrumentIt = m_instruments.find(instrumentId);
            if (instrumentIt == m_instruments.end()) {
                continue; // Skip if instrument doesn't exist
            }
            
            const auto& instrument = instrumentIt->second;
            
            // Calculate base amplitude - reduce as more notes are active
            float baseAmplitude = 0.15f / std::sqrt(static_cast<float>(notes.size()));
            
            // Apply instrument volume
            baseAmplitude *= instrument.volume;
            
            // Generate sine waves for each note
            for (int note : notes) {
                // Calculate frequency based on MIDI note number
                float frequency = midiNoteToFrequency(note);
                
                // Get or initialize phase for this note
                if (m_notePhases[instrumentId].find(note) == m_notePhases[instrumentId].end()) {
                    m_notePhases[instrumentId][note] = 0.0f;
                }
                float& phase = m_notePhases[instrumentId][note];
                
                // Apply velocity scaling if available
                float amplitude = baseAmplitude;
                if (m_noteVelocities.find(instrumentId) != m_noteVelocities.end() &&
                    m_noteVelocities[instrumentId].find(note) != m_noteVelocities[instrumentId].end()) {
                    int velocity = m_noteVelocities[instrumentId][note];
                    amplitude *= static_cast<float>(velocity) / 127.0f;
                }
                
                // Apply master volume
                amplitude *= masterVolume;
                
                // Generate sine wave for this note
                for (int i = 0; i < numFrames; i++) {
                    float sample = amplitude * std::sin(phase);
                    
                    // Mix into output buffer (stereo)
                    buffer[i * 2] += sample;       // Left channel
                    buffer[i * 2 + 1] += sample;   // Right channel
                    
                    // Update phase
                    phase += 2.0f * M_PI * frequency / m_sampleRate;
                    
                    // Keep phase in the range [0, 2π]
                    if (phase >= 2.0f * M_PI) {
                        phase -= 2.0f * M_PI;
                    }
                }
            }
        }
        
        // Apply soft limiting to prevent clipping
        for (int i = 0; i < numFrames * 2; i++) {
            // Soft clipping using tanh
            buffer[i] = std::tanh(buffer[i]);
        }
        
        if (hasActiveNotes) {
            LOGD("Rendered audio frame with active notes (%d samples)", numFrames);
        }
    } catch (const std::exception& e) {
        LOGE("Exception in renderAudio: %s", e.what());
        // Clear buffer in case of exception to prevent undefined behavior
        if (buffer) {
            for (int i = 0; i < numFrames * 2; i++) {
                buffer[i] = 0.0f;
            }
        }
    } catch (...) {
        LOGE("Unknown exception in renderAudio");
        // Clear buffer in case of exception to prevent undefined behavior
        if (buffer) {
            for (int i = 0; i < numFrames * 2; i++) {
                buffer[i] = 0.0f;
            }
        }
    }
}

// Send note on event
bool InstrumentManager::sendNoteOn(int instrumentId, int noteNumber, int velocity) {
    try {
        LOGI("Note ON: instrument=%d, note=%d, velocity=%d", instrumentId, noteNumber, velocity);
        
        if (!m_isInitialized) {
            LOGE("InstrumentManager not initialized");
            return false;
        }
        
        // Validate parameters
        if (noteNumber < 0 || noteNumber >= MAX_NOTES) {
            LOGE("Invalid note number: %d (must be 0-%d)", noteNumber, MAX_NOTES - 1);
            return false;
        }
        
        if (velocity < 1 || velocity > 127) {
            // Clamp velocity to valid range
            velocity = std::max(1, std::min(127, velocity));
            LOGW("Note velocity clamped to valid range: %d", velocity);
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the instrument exists
        auto it = m_instruments.find(instrumentId);
        if (it == m_instruments.end()) {
            LOGE("Instrument with ID %d not found for note on", instrumentId);
            return false;
        }
        
        // Store the velocity
        m_noteVelocities[instrumentId][noteNumber] = velocity;
        
        // Add the note to active notes
        m_activeNotes[instrumentId].insert(noteNumber);
        
        LOGI("Added note %d to active notes for instrument %d with velocity %d", 
             noteNumber, instrumentId, velocity);
        
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in sendNoteOn: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in sendNoteOn");
        return false;
    }
}

// Send note off event
bool InstrumentManager::sendNoteOff(int instrumentId, int noteNumber) {
    try {
        LOGI("Note OFF: instrument=%d, note=%d", instrumentId, noteNumber);
        
        if (!m_isInitialized) {
            LOGE("InstrumentManager not initialized");
            return false;
        }
        
        // Validate parameters
        if (noteNumber < 0 || noteNumber >= MAX_NOTES) {
            LOGE("Invalid note number: %d (must be 0-%d)", noteNumber, MAX_NOTES - 1);
            return false;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the instrument exists
        auto it = m_instruments.find(instrumentId);
        if (it == m_instruments.end()) {
            LOGE("Instrument with ID %d not found for note off", instrumentId);
            return false;
        }
        
        // Remove the note from active notes
        bool wasActive = false;
        if (m_activeNotes.find(instrumentId) != m_activeNotes.end()) {
            auto& notes = m_activeNotes[instrumentId];
            auto noteIt = notes.find(noteNumber);
            
            if (noteIt != notes.end()) {
                notes.erase(noteIt);
                wasActive = true;
                LOGI("Removed note %d from active notes for instrument %d", noteNumber, instrumentId);
            } else {
                LOGW("Note %d was not active for instrument %d", noteNumber, instrumentId);
            }
            
            // Clean up empty sets
            if (notes.empty()) {
                m_activeNotes.erase(instrumentId);
                LOGD("Removed empty note set for instrument %d", instrumentId);
            }
        }
        
        // Clean up velocity map
        if (m_noteVelocities.find(instrumentId) != m_noteVelocities.end()) {
            auto& velocities = m_noteVelocities[instrumentId];
            velocities.erase(noteNumber);
            
            // Clean up empty maps
            if (velocities.empty()) {
                m_noteVelocities.erase(instrumentId);
            }
        }
        
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in sendNoteOff: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in sendNoteOff");
        return false;
    }
}

std::vector<int> InstrumentManager::getLoadedInstrumentIds() {
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        std::vector<int> ids;
        
        for (const auto& pair : m_instruments) {
            ids.push_back(pair.first);
        }
        
        LOGD("Retrieved %zu loaded instrument IDs", ids.size());
        return ids;
    } catch (const std::exception& e) {
        LOGE("Exception in getLoadedInstrumentIds: %s", e.what());
        return std::vector<int>();
    }
}

int InstrumentManager::generateUniqueId() {
    static int nextId = 1;
    return nextId++;
}

bool InstrumentManager::setInstrumentVolume(int instrumentId, float volume) {
    LOGD("Setting volume for instrument %d to %f", instrumentId, volume);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        auto it = m_instruments.find(instrumentId);
        if (it == m_instruments.end()) {
            LOGW("Instrument with ID %d not found for volume setting", instrumentId);
            return false;
        }
        
        // Clamp volume to valid range
        volume = std::max(0.0f, std::min(1.0f, volume));
        
        // Set the instrument volume
        it->second.volume = volume;
        
        LOGD("Volume changed: instrument=%d, volume=%f", instrumentId, volume);
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in setInstrumentVolume: %s", e.what());
        return false;
    }
} 