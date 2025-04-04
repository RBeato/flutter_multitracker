/// Represents a MIDI note in a track
class Note {
  /// The ID of the track this note belongs to
  final int? trackId;
  
  /// MIDI note number (0-127)
  final int noteNumber;
  
  /// Velocity (0-127)
  final int velocity;
  
  /// Starting position in beats
  final double startBeat;
  
  /// Duration in beats
  final double durationBeats;

  /// Creates a new note
  Note({
    this.trackId,
    required this.noteNumber,
    required this.velocity,
    required this.startBeat,
    required this.durationBeats,
  });

  /// Returns the beat position where the note ends
  double get endBeat => startBeat + durationBeats;

  @override
  String toString() {
    final trackInfo = trackId != null ? 'trackId: $trackId, ' : '';
    return 'Note{${trackInfo}note: $noteNumber, velocity: $velocity, start: $startBeat, duration: $durationBeats}';
  }
} 