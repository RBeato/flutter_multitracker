#ifndef SEQUENCE_MANAGER_H
#define SEQUENCE_MANAGER_H

#include <vector>
#include <map>
#include <set>
#include <mutex>
#include <atomic>
#include <string>

class InstrumentManager;

// Structure to represent a note
struct Note {
    int id;
    int noteNumber;
    int velocity;
    double startTime;
    double duration;
};

// Structure to represent a track
struct Track {
    int id;
    int instrumentId;
    std::map<int, Note> notes;
    float volume;
};

// Structure to represent a sequence
struct Sequence {
    int id;
    int tempo;
    std::map<int, Track> tracks;
    bool isPlaying;
};

class SequenceManager {
public:
    explicit SequenceManager(InstrumentManager* instrumentManager);
    ~SequenceManager();

    // Initialize the sequence manager
    bool init();

    // Sequence operations
    int createSequence(int tempo);
    bool deleteSequence(int sequenceId);

    // Track operations
    int addTrack(int sequenceId, int instrumentId);
    bool deleteTrack(int sequenceId, int trackId);

    // Note operations
    int addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startTime, double duration);
    bool deleteNote(int sequenceId, int trackId, int noteId);

    // Playback control
    bool startPlayback(int sequenceId);
    bool stopPlayback();

private:
    // Member variables
    InstrumentManager* m_instrumentManager;
    std::map<int, Sequence> m_sequences;
    int m_nextSequenceId;
    int m_nextTrackId;
    int m_nextNoteId;
    int m_activeSequenceId;
    std::atomic<bool> m_isPlaying;
    std::mutex m_mutex;

    // Process active notes
    void processActiveNotes();
};

#endif // SEQUENCE_MANAGER_H 