/// Represents a note event in a sequence track
class Note {
  /// The unique ID of the note (used for editing/removing the note)
  final int id;
  
  /// The MIDI note number (0-127)
  final int noteNumber;
  
  /// The MIDI velocity value (0-127)
  final int velocity;
  
  /// The beat position where the note starts
  final double startBeat;
  
  /// The duration of the note in beats
  final double durationBeats;

  /// Creates a new Note instance
  const Note({
    required this.id,
    required this.noteNumber,
    required this.velocity,
    required this.startBeat,
    required this.durationBeats,
  });

  /// Returns the beat position where the note ends
  double get endBeat => startBeat + durationBeats;

  @override
  String toString() {
    return 'Note(id: $id, noteNumber: $noteNumber, velocity: $velocity, startBeat: $startBeat, durationBeats: $durationBeats)';
  }
} 