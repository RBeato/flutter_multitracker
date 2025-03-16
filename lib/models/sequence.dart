import 'track.dart';

/// Represents a complete music sequence
class Sequence {
  /// The unique ID of the sequence
  final int id;
  
  /// Tempo in beats per minute
  double bpm;
  
  /// Time signature numerator (e.g., 4 in 4/4)
  int timeSignatureNumerator;
  
  /// Time signature denominator (e.g., 4 in 4/4)
  int timeSignatureDenominator;
  
  /// List of tracks in the sequence
  final List<Track> tracks;
  
  /// Whether the sequence is currently playing
  bool isPlaying;
  
  /// Whether the sequence is looping
  bool isLooping;
  
  /// Current playback position in beats
  double currentBeat;
  
  /// Total length of the sequence in beats
  double lengthInBeats;

  /// Creates a new Sequence instance
  Sequence({
    required this.id,
    required this.bpm,
    this.timeSignatureNumerator = 4,
    this.timeSignatureDenominator = 4,
    List<Track>? tracks,
    this.isPlaying = false,
    this.isLooping = false,
    this.currentBeat = 0.0,
    this.lengthInBeats = 16.0,
  }) : tracks = tracks ?? [];

  /// Add a track to the sequence
  void addTrack(Track track) {
    tracks.add(track);
  }

  /// Remove a track from the sequence
  bool removeTrack(int trackId) {
    final initialLength = tracks.length;
    tracks.removeWhere((track) => track.id == trackId);
    return tracks.length != initialLength;
  }

  /// Find a track by ID
  Track? findTrack(int trackId) {
    try {
      return tracks.firstWhere((track) => track.id == trackId);
    } catch (e) {
      return null;
    }
  }

  /// Calculate the total length of the sequence based on the latest note end
  void updateLength() {
    double maxEndBeat = 0.0;
    
    for (final track in tracks) {
      for (final note in track.notes) {
        final noteEnd = note.startBeat + note.durationBeats;
        if (noteEnd > maxEndBeat) {
          maxEndBeat = noteEnd;
        }
      }
    }
    
    // Add one bar of space after the last note
    final beatsPerBar = timeSignatureNumerator.toDouble();
    lengthInBeats = maxEndBeat + beatsPerBar;
  }

  @override
  String toString() {
    return 'Sequence(id: $id, bpm: $bpm, timeSignature: $timeSignatureNumerator/$timeSignatureDenominator, tracks: ${tracks.length})';
  }
} 