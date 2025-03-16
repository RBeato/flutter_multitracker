import 'package:flutter/foundation.dart';

/// A musical sequence containing tracks and playback settings.
class Sequence {
  /// Unique identifier for the sequence.
  final int id;
  
  /// Tempo in beats per minute.
  double tempo;
  
  /// Current playback position in beats.
  double position;
  
  /// Whether the sequence is currently playing.
  bool isPlaying;
  
  /// Whether looping is enabled.
  bool loopEnabled;
  
  /// Loop start position in beats.
  double loopStartBeat;
  
  /// Loop end position in beats.
  double loopEndBeat;
  
  /// End position in beats (sequence will stop at this point if not looping).
  double endBeat;
  
  /// Tracks in this sequence.
  final List<Track> tracks;
  
  /// Creates a new sequence.
  Sequence({
    required this.id,
    this.tempo = 120.0,
    this.position = 0.0,
    this.isPlaying = false,
    this.loopEnabled = false,
    this.loopStartBeat = 0.0,
    this.loopEndBeat = 4.0,
    this.endBeat = double.infinity,
    List<Track>? tracks,
  }) : tracks = tracks ?? [];
  
  /// Adds a track to this sequence.
  void addTrack(Track track) {
    tracks.add(track);
  }
  
  /// Removes a track from this sequence.
  void removeTrack(Track track) {
    tracks.removeWhere((t) => t.id == track.id);
  }
  
  /// Gets a track by ID.
  Track? getTrack(int trackId) {
    try {
      return tracks.firstWhere((track) => track.id == trackId);
    } catch (e) {
      return null;
    }
  }
  
  @override
  String toString() {
    return 'Sequence(id: $id, tempo: $tempo, tracks: ${tracks.length})';
  }
}

/// A track within a sequence, containing notes and associated with an instrument.
class Track {
  /// Unique identifier for the track.
  final int id;
  
  /// ID of the instrument used for this track.
  final int instrumentId;
  
  /// Name of the track.
  String name;
  
  /// Volume level (0.0 to 1.0).
  double volume;
  
  /// Whether the track is muted.
  bool muted;
  
  /// Whether the track is soloed.
  bool soloed;
  
  /// Notes in this track.
  final List<Note> notes;
  
  /// Creates a new track.
  Track({
    required this.id,
    required this.instrumentId,
    this.name = '',
    this.volume = 1.0,
    this.muted = false,
    this.soloed = false,
    List<Note>? notes,
  }) : notes = notes ?? [];
  
  /// Adds a note to this track.
  void addNote(Note note) {
    notes.add(note);
    // Sort notes by start time
    notes.sort((a, b) => a.startBeat.compareTo(b.startBeat));
  }
  
  /// Removes a note from this track.
  void removeNote(Note note) {
    notes.removeWhere((n) => n.id == note.id);
  }
  
  /// Gets a note by ID.
  Note? getNote(int noteId) {
    try {
      return notes.firstWhere((note) => note.id == noteId);
    } catch (e) {
      return null;
    }
  }
  
  @override
  String toString() {
    return 'Track(id: $id, instrumentId: $instrumentId, name: $name, notes: ${notes.length})';
  }
}

/// A musical note within a track.
class Note {
  /// Unique identifier for the note.
  final int id;
  
  /// MIDI note number (0-127).
  final int noteNumber;
  
  /// Velocity (0-127).
  final int velocity;
  
  /// Start time in beats.
  final double startBeat;
  
  /// Duration in beats.
  final double durationBeats;
  
  /// Creates a new note.
  Note({
    required this.id,
    required this.noteNumber,
    required this.velocity,
    required this.startBeat,
    required this.durationBeats,
  });
  
  @override
  String toString() {
    return 'Note(id: $id, noteNumber: $noteNumber, startBeat: $startBeat, durationBeats: $durationBeats)';
  }
}

/// An instrument that can be used to play notes.
class Instrument {
  /// Unique identifier for the instrument.
  final int id;
  
  /// Name of the instrument.
  final String name;
  
  /// Type of the instrument.
  final String type;
  
  /// Volume level (0.0 to 1.0).
  double volume;
  
  /// Attack time in seconds.
  double attack;
  
  /// Decay time in seconds.
  double decay;
  
  /// Sustain level (0.0 to 1.0).
  double sustain;
  
  /// Release time in seconds.
  double release;
  
  /// Creates a new instrument.
  Instrument({
    required this.id,
    required this.name,
    required this.type,
    this.volume = 1.0,
    this.attack = 0.01,
    this.decay = 0.05,
    this.sustain = 0.7,
    this.release = 0.3,
  });
  
  @override
  String toString() {
    return 'Instrument(id: $id, name: $name, type: $type)';
  }
} 