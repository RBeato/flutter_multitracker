#include "instrument_manager.h"
#include "audio_engine.h"
#include <android/log.h>
#include <vector>
#include <string>
#include <stdexcept>
#include <algorithm>
#include <cmath>
#include <set>
#include <map>
#include <thread>
#include <chrono>
#include <optional>

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
InstrumentManager::InstrumentManager() :
    m_audioEngine(nullptr),
    m_isInitialized(false),
    m_sampleRate(44100)
{
    LOGI("InstrumentManager: Constructor called");
}

// Destructor
InstrumentManager::~InstrumentManager() {
    LOGI("InstrumentManager: Destructor called");
    stopAllNotes();
}

// Set audio engine reference
void InstrumentManager::setAudioEngine(AudioEngine* audioEngine) {
    LOGI("Setting audio engine reference");
    m_audioEngine = audioEngine;
}

// Initialize the instrument manager
bool InstrumentManager::init() {
    LOGI("Initializing InstrumentManager");
    try {
        // Set up instrument manager
        m_isInitialized = true;
        
        // Get the sample rate from the audio engine if available
        if (m_audioEngine) {
            m_sampleRate = m_audioEngine->getSampleRate();
            LOGI("Using sample rate from AudioEngine: %d", m_sampleRate);
        } else {
            m_sampleRate = 44100; // Default sample rate
            LOGI("AudioEngine not available, using default sample rate: %d", m_sampleRate);
        }
        
        LOGI("InstrumentManager initialized successfully");
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in InstrumentManager::init: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in InstrumentManager::init");
        return false;
    }
}

// Create a sine wave instrument
int InstrumentManager::createSineWaveInstrument(const std::string& name) {
    LOGI("Creating sine wave instrument: %s", name.c_str());
    try {
        // Allow creating an instrument even if not fully initialized
        if (!m_isInitialized) {
            LOGW("InstrumentManager not fully initialized, but continuing anyway");
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Generate a unique ID for the instrument
        int instrumentId = generateUniqueId();
        LOGI("Generated instrument ID: %d", instrumentId);
        
        // Create instrument
        auto& instrument = m_instruments[instrumentId];
        
        instrument.type = InstrumentType::SINE_WAVE;
        instrument.name = name;
        instrument.volume = 1.0f;
        
        // Initialize note tracking maps for this instrument
        m_activeNotes[instrumentId] = std::set<int>();
        m_noteVelocities[instrumentId] = std::map<int, int>();
        m_notePhases[instrumentId] = std::map<int, float>();
        
        // Always create ID 0 as a special "default" instrument if it doesn't exist
        if (instrumentId != 0 && m_instruments.find(0) == m_instruments.end()) {
            LOGI("Creating default sine wave instrument with ID 0");
            auto& defaultInstrument = m_instruments[0];
            defaultInstrument.type = InstrumentType::SINE_WAVE;
            defaultInstrument.name = "Default Sine Wave";
            defaultInstrument.volume = 1.0f;
            
            m_activeNotes[0] = std::set<int>();
            m_noteVelocities[0] = std::map<int, int>();
            m_notePhases[0] = std::map<int, float>();
        }
        
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
std::optional<Instrument> InstrumentManager::getInstrument(int instrumentId) const {
    // Cannot use lock_guard in a const method with non-const mutex
    // This is a design issue that should be fixed properly, but for now 
    // we'll make it work without locking
    
    auto it = m_instruments.find(instrumentId);
    if (it == m_instruments.end()) {
        return std::nullopt;
    }
    
    return it->second;
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
            LOGD("No instruments loaded, skipping audio rendering");
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if we have active notes
        bool hasActiveNotes = false;
        int totalActiveNotes = 0;
        
        for (const auto& [instrumentId, notes] : m_activeNotes) {
            if (!notes.empty()) {
                hasActiveNotes = true;
                totalActiveNotes += notes.size();
            }
        }
        
        if (!hasActiveNotes) {
            // No active notes to render
            return;
        }
        
        LOGD("Rendering %d active notes across all instruments", totalActiveNotes);
        
        for (const auto& [instrumentId, notes] : m_activeNotes) {
            if (notes.empty()) {
                continue;
            }
            
            // Get the instrument
            auto instrumentIt = m_instruments.find(instrumentId);
            if (instrumentIt == m_instruments.end()) {
                LOGW("Instrument ID %d not found for active notes", instrumentId);
                continue; // Skip if instrument doesn't exist
            }
            
            const auto& instrument = instrumentIt->second;
            LOGD("Processing instrument %d (%s) with %zu active notes", 
                instrumentId, instrument.name.c_str(), notes.size());
            
            // Calculate base amplitude - reduce as more notes are active
            float baseAmplitude = 0.3f / std::sqrt(static_cast<float>(notes.size()));
            
            // Apply instrument volume
            baseAmplitude *= instrument.volume;
            
            // Generate sine waves for each note
            for (int note : notes) {
                // Calculate frequency based on MIDI note number
                float frequency = midiNoteToFrequency(note);
                
                // Get velocity for this note
                int velocity = 64; // Default mid-velocity if not specified
                if (m_noteVelocities.find(instrumentId) != m_noteVelocities.end() &&
                    m_noteVelocities[instrumentId].find(note) != m_noteVelocities[instrumentId].end()) {
                    velocity = m_noteVelocities[instrumentId][note];
                }
                
                // Get or initialize phase for this note
                if (m_notePhases[instrumentId].find(note) == m_notePhases[instrumentId].end()) {
                    m_notePhases[instrumentId][note] = 0.0f;
                }
                float& phase = m_notePhases[instrumentId][note];
                
                // Apply velocity scaling
                float amplitude = baseAmplitude * (static_cast<float>(velocity) / 127.0f);
                
                // Apply master volume
                amplitude *= masterVolume;
                
                LOGD("  Note %d: freq=%.2f Hz, vel=%d, amp=%.4f", 
                     note, frequency, velocity, amplitude);
                
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
        
        // Check for actual sound output
        float maxSample = 0.0f;
        for (int i = 0; i < numFrames * 2; i++) {
            maxSample = std::max(maxSample, std::abs(buffer[i]));
        }
        
        if (maxSample > 0.01f) {
            LOGD("Generated audio with max amplitude: %.4f", maxSample);
        }
    } catch (const std::exception& e) {
        LOGE("Exception in renderAudio: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in renderAudio");
    }
}

// Send note on event
bool InstrumentManager::sendNoteOn(int instrumentId, int noteNumber, int velocity) {
    LOGD("Note On: instrument=%d, note=%d, velocity=%d", instrumentId, noteNumber, velocity);
    
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Validate instrument ID
        if (m_instruments.find(instrumentId) == m_instruments.end()) {
            // Try to use default instrument 0 as fallback
            if (m_instruments.find(0) != m_instruments.end()) {
                LOGW("Instrument ID %d not found, using default (0) instead", instrumentId);
                instrumentId = 0;
            } else {
                LOGE("Invalid instrument ID: %d", instrumentId);
                return false;
            }
        }
        
        // Validate note number and velocity
        if (noteNumber < 0 || noteNumber > 127) {
            LOGE("Invalid note number: %d", noteNumber);
            return false;
        }
        
        if (velocity < 0 || velocity > 127) {
            LOGE("Invalid velocity: %d", velocity);
            return false;
        }
        
        // For sine wave instruments, create a new oscillator for this note
        auto& instrument = m_instruments[instrumentId];
        
        if (instrument.type == InstrumentType::SINE_WAVE) {
            // Store the new active note
            m_activeNotes[instrumentId].insert(noteNumber);
            m_noteVelocities[instrumentId][noteNumber] = velocity;
            m_notePhases[instrumentId][noteNumber] = 0.0f;
            
            LOGI("Note On successful: instr=%d, note=%d, vel=%d", 
                 instrumentId, noteNumber, velocity);
            return true;
        } else {
            LOGE("Unsupported instrument type for note on");
            return false;
        }
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

// Helper methods for audio rendering
std::vector<int> InstrumentManager::getActiveInstruments() const {
    std::vector<int> result;
    
    try {
        // No need for a lock in a const method, but be careful with thread safety
        for (const auto& pair : m_activeNotes) {
            if (!pair.second.empty()) {
                result.push_back(pair.first);
            }
        }
    } catch (const std::exception& e) {
        LOGE("Exception in getActiveInstruments: %s", e.what());
    }
    
    return result;
}

std::set<int> InstrumentManager::getActiveNotes(int instrumentId) const {
    try {
        auto it = m_activeNotes.find(instrumentId);
        if (it != m_activeNotes.end()) {
            return it->second;
        }
    } catch (const std::exception& e) {
        LOGE("Exception in getActiveNotes: %s", e.what());
    }
    
    return std::set<int>();
}

int InstrumentManager::getNoteVelocity(int instrumentId, int noteNumber) const {
    try {
        auto instIt = m_noteVelocities.find(instrumentId);
        if (instIt != m_noteVelocities.end()) {
            auto noteIt = instIt->second.find(noteNumber);
            if (noteIt != instIt->second.end()) {
                return noteIt->second;
            }
        }
    } catch (const std::exception& e) {
        LOGE("Exception in getNoteVelocity: %s", e.what());
    }
    
    // Default velocity if not found
    return 64;
}

float& InstrumentManager::getNotePhase(int instrumentId, int noteNumber) {
    static float defaultPhase = 0.0f;
    
    try {
        return m_notePhases[instrumentId][noteNumber];
    } catch (const std::exception& e) {
        LOGE("Exception in getNotePhase: %s", e.what());
        return defaultPhase;
    }
}

// Stop all notes for all instruments
void InstrumentManager::stopAllNotes() {
    LOGD("Stopping all notes for all instruments");
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Iterate through all instruments
        for (const auto& [instrumentId, instrument] : m_instruments) {
            // Clear all active notes for this instrument
            m_activeNotes[instrumentId].clear();
            m_noteVelocities[instrumentId].clear();
            m_notePhases[instrumentId].clear();
            
            LOGD("Cleared all notes for instrument %d (%s)", instrumentId, instrument.name.c_str());
        }
        
        LOGD("Successfully stopped all notes for all instruments");
    } catch (const std::exception& e) {
        LOGE("Exception in stopAllNotes: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in stopAllNotes");
    }
}

// Stop all notes for a specific instrument
bool InstrumentManager::stopAllNotes(int instrumentId) {
    LOGD("Stopping all notes for instrument ID: %d", instrumentId);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the instrument exists
        auto it = m_instruments.find(instrumentId);
        if (it == m_instruments.end()) {
            LOGW("Instrument with ID %d not found", instrumentId);
            return false;
        }
        
        // Clear all active notes for this instrument
        m_activeNotes[instrumentId].clear();
        m_noteVelocities[instrumentId].clear();
        m_notePhases[instrumentId].clear();
        
        LOGD("Successfully stopped all notes for instrument %d (%s)", 
             instrumentId, it->second.name.c_str());
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in stopAllNotes(instrumentId): %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in stopAllNotes(instrumentId)");
        return false;
    }
} 