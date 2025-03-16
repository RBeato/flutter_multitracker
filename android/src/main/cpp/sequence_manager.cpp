#include "sequence_manager.h"
#include "instrument_manager.h"
#include <android/log.h>
#include <algorithm>
#include <cmath>

#define LOG_TAG "SequenceManager"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

SequenceManager::SequenceManager(InstrumentManager* instrumentManager)
    : m_instrumentManager(instrumentManager),
      m_nextSequenceId(1),
      m_nextTrackId(1),
      m_nextNoteId(1),
      m_activeSequenceId(-1),
      m_isPlaying(false) {
    LOGD("SequenceManager created");
}

SequenceManager::~SequenceManager() {
    LOGD("SequenceManager destructor called");
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_sequences.clear();
        LOGD("SequenceManager destroyed successfully");
    } catch (const std::exception& e) {
        LOGE("Exception in SequenceManager destructor: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in SequenceManager destructor");
    }
}

bool SequenceManager::init() {
    LOGD("Initializing SequenceManager");
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_sequences.clear();
        m_nextSequenceId = 1;
        m_nextTrackId = 1;
        m_nextNoteId = 1;
        m_activeSequenceId = -1;
        m_isPlaying = false;
        LOGD("SequenceManager initialized successfully");
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in SequenceManager::init: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in SequenceManager::init");
        return false;
    }
}

int SequenceManager::createSequence(int tempo) {
    LOGD("Creating sequence with tempo: %d", tempo);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Validate tempo
        if (tempo <= 0) {
            LOGW("Invalid tempo: %d, using default 120", tempo);
            tempo = 120;
        }
        
        // Create a new sequence
        int sequenceId = m_nextSequenceId++;
        Sequence& sequence = m_sequences[sequenceId];
        sequence.id = sequenceId;
        sequence.tempo = tempo;
        sequence.isPlaying = false;
        
        LOGD("Created sequence with ID: %d", sequenceId);
        return sequenceId;
    } catch (const std::exception& e) {
        LOGE("Exception in createSequence: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("Unknown exception in createSequence");
        return -1;
    }
}

bool SequenceManager::deleteSequence(int sequenceId) {
    LOGD("Deleting sequence with ID: %d", sequenceId);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the sequence exists
        auto it = m_sequences.find(sequenceId);
        if (it == m_sequences.end()) {
            LOGW("Sequence with ID %d not found", sequenceId);
            return false;
        }
        
        // Stop playback if this sequence is active
        if (m_activeSequenceId == sequenceId && m_isPlaying) {
            stopPlayback();
        }
        
        // Remove the sequence
        m_sequences.erase(it);
        
        LOGD("Deleted sequence with ID: %d", sequenceId);
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in deleteSequence: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in deleteSequence");
        return false;
    }
}

int SequenceManager::addTrack(int sequenceId, int instrumentId) {
    LOGD("Adding track to sequence %d with instrument %d", sequenceId, instrumentId);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the sequence exists
        auto seqIt = m_sequences.find(sequenceId);
        if (seqIt == m_sequences.end()) {
            LOGW("Sequence with ID %d not found", sequenceId);
            return -1;
        }
        
        // Create a new track
        int trackId = m_nextTrackId++;
        Track& track = seqIt->second.tracks[trackId];
        track.id = trackId;
        track.instrumentId = instrumentId;
        track.volume = 1.0f;
        
        LOGD("Added track with ID %d to sequence %d", trackId, sequenceId);
        return trackId;
    } catch (const std::exception& e) {
        LOGE("Exception in addTrack: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("Unknown exception in addTrack");
        return -1;
    }
}

bool SequenceManager::deleteTrack(int sequenceId, int trackId) {
    LOGD("Deleting track %d from sequence %d", trackId, sequenceId);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the sequence exists
        auto seqIt = m_sequences.find(sequenceId);
        if (seqIt == m_sequences.end()) {
            LOGW("Sequence with ID %d not found", sequenceId);
            return false;
        }
        
        // Check if the track exists
        auto trackIt = seqIt->second.tracks.find(trackId);
        if (trackIt == seqIt->second.tracks.end()) {
            LOGW("Track with ID %d not found in sequence %d", trackId, sequenceId);
            return false;
        }
        
        // Remove the track
        seqIt->second.tracks.erase(trackIt);
        
        LOGD("Deleted track %d from sequence %d", trackId, sequenceId);
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in deleteTrack: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in deleteTrack");
        return false;
    }
}

int SequenceManager::addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startTime, double duration) {
    try {
        LOGI("Adding note to sequence %d, track %d: note=%d, velocity=%d, start=%f, duration=%f",
             sequenceId, trackId, noteNumber, velocity, startTime, duration);
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the InstrumentManager is valid
        if (!m_instrumentManager) {
            LOGE("InstrumentManager is null");
            return -1;
        }
        
        // Check if the sequence exists
        auto seqIt = m_sequences.find(sequenceId);
        if (seqIt == m_sequences.end()) {
            LOGW("Sequence with ID %d not found", sequenceId);
            return -1;
        }
        
        // Check if the track exists
        auto& tracks = seqIt->second.tracks;
        auto trackIt = tracks.find(trackId);
        if (trackIt == tracks.end()) {
            LOGW("Track with ID %d not found in sequence %d", trackId, sequenceId);
            return -1;
        }
        
        // Validate note number (0-127 for MIDI)
        if (noteNumber < 0 || noteNumber > 127) {
            LOGW("Invalid note number: %d (must be 0-127)", noteNumber);
            return -1;
        }
        
        // Validate velocity (1-127 for MIDI, 0 is note off)
        if (velocity < 1 || velocity > 127) {
            velocity = std::max(1, std::min(127, velocity));
            LOGW("Note velocity clamped to valid range: %d", velocity);
        }
        
        // Validate timing
        if (startTime < 0) {
            LOGW("Invalid start time: %f (must be >= 0)", startTime);
            startTime = 0;
        }
        
        if (duration <= 0) {
            LOGW("Invalid duration: %f (must be > 0)", duration);
            duration = 0.1; // Set a small default duration
        }
        
        // Check if the instrument exists
        int instrumentId = trackIt->second.instrumentId;
        Instrument* instrument = m_instrumentManager->getInstrument(instrumentId);
        if (!instrument) {
            LOGW("Instrument with ID %d not found", instrumentId);
            return -1;
        }
        
        // Create a new note
        int noteId = m_nextNoteId++;
        Note& note = trackIt->second.notes[noteId];
        note.id = noteId;
        note.noteNumber = noteNumber;
        note.velocity = velocity;
        note.startTime = startTime;
        note.duration = duration;
        
        LOGI("Added note with ID %d to track %d in sequence %d", noteId, trackId, sequenceId);
        
        // If the sequence is currently playing and the note should start now, trigger it
        if (m_isPlaying && sequenceId == m_activeSequenceId) {
            if (startTime <= 0) {
                // Trigger the note immediately
                bool success = m_instrumentManager->sendNoteOn(instrumentId, noteNumber, velocity);
                if (success) {
                    LOGD("Triggered note %d with velocity %d on instrument %d", noteNumber, velocity, instrumentId);
                } else {
                    LOGW("Failed to trigger note %d on instrument %d", noteNumber, instrumentId);
                }
            }
        }
        
        return noteId;
    } catch (const std::exception& e) {
        LOGE("Exception in addNote: %s", e.what());
        return -1;
    } catch (...) {
        LOGE("Unknown exception in addNote");
        return -1;
    }
}

bool SequenceManager::deleteNote(int sequenceId, int trackId, int noteId) {
    LOGD("Deleting note %d from track %d in sequence %d", noteId, trackId, sequenceId);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the sequence exists
        auto seqIt = m_sequences.find(sequenceId);
        if (seqIt == m_sequences.end()) {
            LOGW("Sequence with ID %d not found", sequenceId);
            return false;
        }
        
        // Check if the track exists
        auto trackIt = seqIt->second.tracks.find(trackId);
        if (trackIt == seqIt->second.tracks.end()) {
            LOGW("Track with ID %d not found in sequence %d", trackId, sequenceId);
            return false;
        }
        
        // Check if the note exists
        auto noteIt = trackIt->second.notes.find(noteId);
        if (noteIt == trackIt->second.notes.end()) {
            LOGW("Note with ID %d not found in track %d", noteId, trackId);
            return false;
        }
        
        // If the note is currently playing, stop it
        if (m_isPlaying && sequenceId == m_activeSequenceId) {
            int instrumentId = trackIt->second.instrumentId;
            int noteNumber = noteIt->second.noteNumber;
            m_instrumentManager->sendNoteOff(instrumentId, noteNumber);
        }
        
        // Remove the note
        trackIt->second.notes.erase(noteIt);
        
        LOGD("Deleted note %d from track %d in sequence %d", noteId, trackId, sequenceId);
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in deleteNote: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in deleteNote");
        return false;
    }
}

bool SequenceManager::startPlayback(int sequenceId) {
    LOGD("Starting playback of sequence %d", sequenceId);
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the sequence exists
        auto seqIt = m_sequences.find(sequenceId);
        if (seqIt == m_sequences.end()) {
            LOGW("Sequence with ID %d not found", sequenceId);
            return false;
        }
        
        // Stop any currently playing sequence
        if (m_isPlaying) {
            stopPlayback();
        }
        
        // Set the active sequence
        m_activeSequenceId = sequenceId;
        seqIt->second.isPlaying = true;
        m_isPlaying = true;
        
        // Trigger all notes that start at time 0
        for (auto& trackPair : seqIt->second.tracks) {
            int instrumentId = trackPair.second.instrumentId;
            
            for (auto& notePair : trackPair.second.notes) {
                const Note& note = notePair.second;
                
                if (note.startTime <= 0) {
                    // Trigger the note immediately
                    bool success = m_instrumentManager->sendNoteOn(instrumentId, note.noteNumber, note.velocity);
                    if (success) {
                        LOGD("Triggered note %d with velocity %d on instrument %d", note.noteNumber, note.velocity, instrumentId);
                    } else {
                        LOGW("Failed to trigger note %d on instrument %d", note.noteNumber, instrumentId);
                    }
                }
            }
        }
        
        LOGI("Started playback of sequence %d", sequenceId);
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in startPlayback: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in startPlayback");
        return false;
    }
}

bool SequenceManager::stopPlayback() {
    LOGD("Stopping playback");
    try {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        if (!m_isPlaying) {
            LOGW("No sequence is currently playing");
            return true;
        }
        
        // Stop all active notes
        if (m_activeSequenceId >= 0) {
            auto seqIt = m_sequences.find(m_activeSequenceId);
            if (seqIt != m_sequences.end()) {
                for (auto& trackPair : seqIt->second.tracks) {
                    int instrumentId = trackPair.second.instrumentId;
                    
                    // Get all active notes for this instrument
                    std::vector<int> activeNotes;
                    for (auto& notePair : trackPair.second.notes) {
                        activeNotes.push_back(notePair.second.noteNumber);
                    }
                    
                    // Send note off for each active note
                    for (int noteNumber : activeNotes) {
                        m_instrumentManager->sendNoteOff(instrumentId, noteNumber);
                    }
                }
                
                seqIt->second.isPlaying = false;
            }
        }
        
        m_activeSequenceId = -1;
        m_isPlaying = false;
        
        LOGI("Playback stopped");
        return true;
    } catch (const std::exception& e) {
        LOGE("Exception in stopPlayback: %s", e.what());
        return false;
    } catch (...) {
        LOGE("Unknown exception in stopPlayback");
        return false;
    }
}

void SequenceManager::processActiveNotes() {
    try {
        if (!m_isPlaying || m_activeSequenceId < 0 || !m_instrumentManager) {
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if the active sequence still exists
        auto seqIt = m_sequences.find(m_activeSequenceId);
        if (seqIt == m_sequences.end()) {
            LOGW("Active sequence %d no longer exists", m_activeSequenceId);
            m_isPlaying = false;
            m_activeSequenceId = -1;
            return;
        }
        
        // Process each track
        for (auto& trackPair : seqIt->second.tracks) {
            int instrumentId = trackPair.second.instrumentId;
            
            // Check if the instrument exists
            Instrument* instrument = m_instrumentManager->getInstrument(instrumentId);
            if (!instrument) {
                LOGW("Instrument %d not found for track %d", instrumentId, trackPair.first);
                continue;
            }
            
            // Process each note
            for (auto& notePair : trackPair.second.notes) {
                const Note& note = notePair.second;
                
                // Process note logic here if needed
                // For now, we're just using the simple note on/off mechanism
            }
        }
    } catch (const std::exception& e) {
        LOGE("Exception in processActiveNotes: %s", e.what());
    } catch (...) {
        LOGE("Unknown exception in processActiveNotes");
    }
} 