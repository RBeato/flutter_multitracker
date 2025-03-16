package com.example.flutter_multitracker;

import android.util.Log;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Manages sequences, tracks, and notes with timing information.
 */
public class SequenceManager {
    private static final String TAG = "SequenceManager";
    
    // Reference to the AudioEngine for playing notes
    private final AudioEngine audioEngine;
    
    // Sequences data
    private final Map<Integer, Sequence> sequences = new HashMap<>();
    private int nextSequenceId = 1;
    
    // Playback state
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    
    /**
     * Constructor.
     */
    public SequenceManager(AudioEngine audioEngine) {
        this.audioEngine = audioEngine;
        isInitialized.set(true);
    }
    
    /**
     * Initialize the sequence manager.
     */
    public boolean init() {
        Log.d(TAG, "Initializing SequenceManager");
        
        if (audioEngine == null) {
            Log.e(TAG, "AudioEngine is null");
            return false;
        }
        
        isInitialized.set(true);
        return true;
    }
    
    /**
     * Create a new sequence.
     */
    public int createSequence(int tempo) {
        Log.d(TAG, "Creating sequence with tempo: " + tempo);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return -1;
        }
        
        // Validate tempo
        if (tempo <= 0) {
            Log.e(TAG, "Invalid tempo: " + tempo);
            return -1;
        }
        
        // Create sequence
        int sequenceId = nextSequenceId++;
        Sequence sequence = new Sequence(sequenceId, tempo);
        sequences.put(sequenceId, sequence);
        
        Log.i(TAG, "Created sequence with ID: " + sequenceId + ", tempo: " + tempo);
        return sequenceId;
    }
    
    /**
     * Delete a sequence.
     */
    public boolean deleteSequence(int sequenceId) {
        Log.d(TAG, "Deleting sequence with ID: " + sequenceId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Stop playback if playing
        Sequence sequence = sequences.get(sequenceId);
        if (sequence.isPlaying) {
            stopPlayback(sequenceId);
        }
        
        // Remove sequence
        sequences.remove(sequenceId);
        
        Log.i(TAG, "Deleted sequence with ID: " + sequenceId);
        return true;
    }
    
    /**
     * Add a track to a sequence.
     */
    public int addTrack(int sequenceId, int instrumentId) {
        Log.d(TAG, "Adding track to sequence " + sequenceId + " with instrument " + instrumentId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return -1;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return -1;
        }
        
        // Create track
        Sequence sequence = sequences.get(sequenceId);
        int trackId = sequence.nextTrackId++;
        Track track = new Track(trackId, instrumentId);
        sequence.tracks.put(trackId, track);
        
        Log.i(TAG, "Added track with ID: " + trackId + " to sequence " + sequenceId);
        return trackId;
    }
    
    /**
     * Delete a track from a sequence.
     */
    public boolean deleteTrack(int sequenceId, int trackId) {
        Log.d(TAG, "Deleting track " + trackId + " from sequence " + sequenceId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Check if track exists
        Sequence sequence = sequences.get(sequenceId);
        if (!sequence.tracks.containsKey(trackId)) {
            Log.e(TAG, "Track with ID " + trackId + " not found in sequence " + sequenceId);
            return false;
        }
        
        // Remove track
        sequence.tracks.remove(trackId);
        
        Log.i(TAG, "Deleted track with ID: " + trackId + " from sequence " + sequenceId);
        return true;
    }
    
    /**
     * Add a note to a track.
     */
    public int addNote(int sequenceId, int trackId, int noteNumber, int velocity, 
                      double startTime, double duration) {
        Log.d(TAG, "Adding note to track " + trackId + " in sequence " + sequenceId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return -1;
        }
        
        // Validate parameters
        if (noteNumber < 0 || noteNumber > 127) {
            Log.e(TAG, "Invalid note number: " + noteNumber);
            return -1;
        }
        
        if (velocity < 1 || velocity > 127) {
            Log.e(TAG, "Invalid velocity: " + velocity);
            return -1;
        }
        
        if (startTime < 0) {
            Log.e(TAG, "Invalid start time: " + startTime);
            return -1;
        }
        
        if (duration <= 0) {
            Log.e(TAG, "Invalid duration: " + duration);
            return -1;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return -1;
        }
        
        // Check if track exists
        Sequence sequence = sequences.get(sequenceId);
        if (!sequence.tracks.containsKey(trackId)) {
            Log.e(TAG, "Track with ID " + trackId + " not found in sequence " + sequenceId);
            return -1;
        }
        
        // Create note
        Track track = sequence.tracks.get(trackId);
        int noteId = track.nextNoteId++;
        Note note = new Note(noteId, noteNumber, velocity, startTime, duration);
        track.notes.put(noteId, note);
        
        // If sequence is playing and note should start now, trigger it
        if (sequence.isPlaying && startTime <= sequence.currentBeat) {
            audioEngine.sendNoteOn(track.instrumentId, noteNumber, velocity);
            note.isPlaying = true;
        }
        
        Log.i(TAG, "Added note with ID: " + noteId + " to track " + trackId + " in sequence " + sequenceId);
        return noteId;
    }
    
    /**
     * Delete a note from a track.
     */
    public boolean deleteNote(int sequenceId, int trackId, int noteId) {
        Log.d(TAG, "Deleting note " + noteId + " from track " + trackId + " in sequence " + sequenceId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Check if track exists
        Sequence sequence = sequences.get(sequenceId);
        if (!sequence.tracks.containsKey(trackId)) {
            Log.e(TAG, "Track with ID " + trackId + " not found in sequence " + sequenceId);
            return false;
        }
        
        // Check if note exists
        Track track = sequence.tracks.get(trackId);
        if (!track.notes.containsKey(noteId)) {
            Log.e(TAG, "Note with ID " + noteId + " not found in track " + trackId);
            return false;
        }
        
        // If note is playing, stop it
        Note note = track.notes.get(noteId);
        if (note.isPlaying) {
            audioEngine.sendNoteOff(track.instrumentId, note.noteNumber);
        }
        
        // Remove note
        track.notes.remove(noteId);
        
        Log.i(TAG, "Deleted note with ID: " + noteId + " from track " + trackId + " in sequence " + sequenceId);
        return true;
    }
    
    /**
     * Start playback of a sequence.
     */
    public boolean startPlayback(int sequenceId) {
        Log.d(TAG, "Starting playback of sequence " + sequenceId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Start playback
        Sequence sequence = sequences.get(sequenceId);
        sequence.isPlaying = true;
        sequence.startTimeMs = System.currentTimeMillis();
        sequence.lastProcessTimeMs = sequence.startTimeMs;
        
        // Trigger notes that start immediately
        for (Track track : sequence.tracks.values()) {
            for (Note note : track.notes.values()) {
                if (note.startBeat <= sequence.currentBeat && 
                    note.startBeat + note.durationBeats > sequence.currentBeat) {
                    audioEngine.sendNoteOn(track.instrumentId, note.noteNumber, note.velocity);
                    note.isPlaying = true;
                }
            }
        }
        
        Log.i(TAG, "Started playback of sequence " + sequenceId);
        return true;
    }
    
    /**
     * Stop playback of a sequence.
     */
    public boolean stopPlayback(int sequenceId) {
        Log.d(TAG, "Stopping playback of sequence " + sequenceId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Stop playback
        Sequence sequence = sequences.get(sequenceId);
        sequence.isPlaying = false;
        
        // Stop all active notes
        for (Track track : sequence.tracks.values()) {
            for (Note note : track.notes.values()) {
                if (note.isPlaying) {
                    audioEngine.sendNoteOff(track.instrumentId, note.noteNumber);
                    note.isPlaying = false;
                }
            }
        }
        
        Log.i(TAG, "Stopped playback of sequence " + sequenceId);
        return true;
    }
    
    /**
     * Process active notes for all playing sequences.
     * This should be called periodically to update playback.
     */
    public void processActiveNotes() {
        if (!isInitialized.get()) {
            return;
        }
        
        long currentTimeMs = System.currentTimeMillis();
        
        for (Sequence sequence : sequences.values()) {
            if (sequence.isPlaying) {
                // Update current beat position
                double elapsedSeconds = (currentTimeMs - sequence.lastProcessTimeMs) / 1000.0;
                double beatsPerSecond = sequence.tempo / 60.0;
                double beatDelta = elapsedSeconds * beatsPerSecond;
                
                sequence.currentBeat += beatDelta;
                sequence.lastProcessTimeMs = currentTimeMs;
                
                // Check for loop
                if (sequence.loopEnabled && sequence.currentBeat >= sequence.loopEndBeat) {
                    double loopLength = sequence.loopEndBeat - sequence.loopStartBeat;
                    sequence.currentBeat = sequence.loopStartBeat + 
                                          (sequence.currentBeat - sequence.loopStartBeat) % loopLength;
                }
                
                // Process notes for each track
                for (Track track : sequence.tracks.values()) {
                    // Check for notes that should start
                    for (Note note : track.notes.values()) {
                        // Note should start
                        if (!note.isPlaying && 
                            note.startBeat <= sequence.currentBeat && 
                            note.startBeat + note.durationBeats > sequence.currentBeat) {
                            audioEngine.sendNoteOn(track.instrumentId, note.noteNumber, note.velocity);
                            note.isPlaying = true;
                        }
                        // Note should stop
                        else if (note.isPlaying && 
                                note.startBeat + note.durationBeats <= sequence.currentBeat) {
                            audioEngine.sendNoteOff(track.instrumentId, note.noteNumber);
                            note.isPlaying = false;
                        }
                    }
                }
                
                // Check if sequence reached the end
                if (!sequence.loopEnabled && sequence.currentBeat >= sequence.endBeat) {
                    stopPlayback(sequence.id);
                }
            }
        }
    }
    
    /**
     * Set the tempo of a sequence.
     */
    public boolean setTempo(int sequenceId, double tempo) {
        Log.d(TAG, "Setting tempo of sequence " + sequenceId + " to " + tempo);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Validate tempo
        if (tempo <= 0) {
            Log.e(TAG, "Invalid tempo: " + tempo);
            return false;
        }
        
        // Set tempo
        Sequence sequence = sequences.get(sequenceId);
        sequence.tempo = tempo;
        
        Log.i(TAG, "Set tempo of sequence " + sequenceId + " to " + tempo);
        return true;
    }
    
    /**
     * Set the loop range of a sequence.
     */
    public boolean setLoop(int sequenceId, double loopStartBeat, double loopEndBeat) {
        Log.d(TAG, "Setting loop range of sequence " + sequenceId + " to " + 
              loopStartBeat + " - " + loopEndBeat);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Validate loop range
        if (loopStartBeat < 0 || loopEndBeat <= loopStartBeat) {
            Log.e(TAG, "Invalid loop range: " + loopStartBeat + " - " + loopEndBeat);
            return false;
        }
        
        // Set loop range
        Sequence sequence = sequences.get(sequenceId);
        sequence.loopStartBeat = loopStartBeat;
        sequence.loopEndBeat = loopEndBeat;
        sequence.loopEnabled = true;
        
        Log.i(TAG, "Set loop range of sequence " + sequenceId + " to " + 
              loopStartBeat + " - " + loopEndBeat);
        return true;
    }
    
    /**
     * Disable looping for a sequence.
     */
    public boolean unsetLoop(int sequenceId) {
        Log.d(TAG, "Disabling loop for sequence " + sequenceId);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Disable loop
        Sequence sequence = sequences.get(sequenceId);
        sequence.loopEnabled = false;
        
        Log.i(TAG, "Disabled loop for sequence " + sequenceId);
        return true;
    }
    
    /**
     * Set the playback position of a sequence.
     */
    public boolean setBeat(int sequenceId, double beat) {
        Log.d(TAG, "Setting beat position of sequence " + sequenceId + " to " + beat);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Validate beat
        if (beat < 0) {
            Log.e(TAG, "Invalid beat position: " + beat);
            return false;
        }
        
        // Stop all active notes
        Sequence sequence = sequences.get(sequenceId);
        for (Track track : sequence.tracks.values()) {
            for (Note note : track.notes.values()) {
                if (note.isPlaying) {
                    audioEngine.sendNoteOff(track.instrumentId, note.noteNumber);
                    note.isPlaying = false;
                }
            }
        }
        
        // Set beat position
        sequence.currentBeat = beat;
        sequence.lastProcessTimeMs = System.currentTimeMillis();
        
        // If sequence is playing, trigger notes at the new position
        if (sequence.isPlaying) {
            for (Track track : sequence.tracks.values()) {
                for (Note note : track.notes.values()) {
                    if (note.startBeat <= sequence.currentBeat && 
                        note.startBeat + note.durationBeats > sequence.currentBeat) {
                        audioEngine.sendNoteOn(track.instrumentId, note.noteNumber, note.velocity);
                        note.isPlaying = true;
                    }
                }
            }
        }
        
        Log.i(TAG, "Set beat position of sequence " + sequenceId + " to " + beat);
        return true;
    }
    
    /**
     * Set the end beat of a sequence.
     */
    public boolean setEndBeat(int sequenceId, double endBeat) {
        Log.d(TAG, "Setting end beat of sequence " + sequenceId + " to " + endBeat);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Validate end beat
        if (endBeat <= 0) {
            Log.e(TAG, "Invalid end beat: " + endBeat);
            return false;
        }
        
        // Set end beat
        Sequence sequence = sequences.get(sequenceId);
        sequence.endBeat = endBeat;
        
        Log.i(TAG, "Set end beat of sequence " + sequenceId + " to " + endBeat);
        return true;
    }
    
    /**
     * Get the current beat position of a sequence.
     */
    public double getPosition(int sequenceId) {
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return 0.0;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return 0.0;
        }
        
        // Get current beat position
        Sequence sequence = sequences.get(sequenceId);
        
        // If playing, update position based on elapsed time
        if (sequence.isPlaying) {
            long currentTimeMs = System.currentTimeMillis();
            double elapsedSeconds = (currentTimeMs - sequence.lastProcessTimeMs) / 1000.0;
            double beatsPerSecond = sequence.tempo / 60.0;
            double beatDelta = elapsedSeconds * beatsPerSecond;
            
            return sequence.currentBeat + beatDelta;
        }
        
        return sequence.currentBeat;
    }
    
    /**
     * Check if a sequence is playing.
     */
    public boolean getIsPlaying(int sequenceId) {
        if (!isInitialized.get()) {
            Log.e(TAG, "SequenceManager not initialized");
            return false;
        }
        
        // Check if sequence exists
        if (!sequences.containsKey(sequenceId)) {
            Log.e(TAG, "Sequence with ID " + sequenceId + " not found");
            return false;
        }
        
        // Get playing state
        Sequence sequence = sequences.get(sequenceId);
        return sequence.isPlaying;
    }
    
    /**
     * Clean up resources.
     */
    public void cleanup() {
        Log.d(TAG, "Cleaning up SequenceManager");
        
        // Stop all sequences
        for (Sequence sequence : sequences.values()) {
            if (sequence.isPlaying) {
                stopPlayback(sequence.id);
            }
        }
        
        // Clear sequences
        sequences.clear();
        
        isInitialized.set(false);
        
        Log.i(TAG, "SequenceManager cleaned up");
    }
    
    /**
     * Sequence data class.
     */
    private static class Sequence {
        final int id;
        double tempo;
        double currentBeat = 0.0;
        double endBeat = Double.MAX_VALUE;
        boolean isPlaying = false;
        long startTimeMs = 0;
        long lastProcessTimeMs = 0;
        
        // Loop state
        boolean loopEnabled = false;
        double loopStartBeat = 0.0;
        double loopEndBeat = 4.0;
        
        // Tracks
        final Map<Integer, Track> tracks = new HashMap<>();
        int nextTrackId = 1;
        
        Sequence(int id, double tempo) {
            this.id = id;
            this.tempo = tempo;
        }
    }
    
    /**
     * Track data class.
     */
    private static class Track {
        final int id;
        final int instrumentId;
        final Map<Integer, Note> notes = new HashMap<>();
        int nextNoteId = 1;
        
        Track(int id, int instrumentId) {
            this.id = id;
            this.instrumentId = instrumentId;
        }
    }
    
    /**
     * Note data class.
     */
    private static class Note {
        final int id;
        final int noteNumber;
        final int velocity;
        final double startBeat;
        final double durationBeats;
        boolean isPlaying = false;
        
        Note(int id, int noteNumber, int velocity, double startBeat, double durationBeats) {
            this.id = id;
            this.noteNumber = noteNumber;
            this.velocity = velocity;
            this.startBeat = startBeat;
            this.durationBeats = durationBeats;
        }
    }
} 