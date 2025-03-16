import 'automation.dart';
import 'note.dart';

/// Represents a track in a sequence
class Track {
  /// The unique ID of the track
  final int id;
  
  /// The ID of the instrument assigned to this track
  final int instrumentId;
  
  /// The name of the track (optional)
  final String? name;
  
  /// List of notes in the track
  final List<Note> notes;
  
  /// List of volume automation points
  final List<VolumeAutomation> volumeAutomation;
  
  /// Current volume level (0.0 to 1.0)
  double volume;
  
  /// Whether the track is muted
  bool muted;
  
  /// Whether the track is soloed
  bool soloed;

  /// Creates a new Track instance
  Track({
    required this.id,
    required this.instrumentId,
    this.name,
    List<Note>? notes,
    List<VolumeAutomation>? volumeAutomation,
    this.volume = 1.0,
    this.muted = false,
    this.soloed = false,
  }) : 
    notes = notes ?? [],
    volumeAutomation = volumeAutomation ?? [];

  /// Add a note to the track
  void addNote(Note note) {
    notes.add(note);
  }

  /// Remove a note from the track
  bool removeNote(int noteId) {
    final initialLength = notes.length;
    notes.removeWhere((note) => note.id == noteId);
    return notes.length != initialLength;
  }

  /// Add a volume automation point
  void addVolumeAutomation(VolumeAutomation automation) {
    volumeAutomation.add(automation);
    // Sort automation points by beat position
    volumeAutomation.sort((a, b) => a.beat.compareTo(b.beat));
  }

  /// Remove a volume automation point
  bool removeVolumeAutomation(int automationId) {
    final initialLength = volumeAutomation.length;
    volumeAutomation.removeWhere((automation) => automation.id == automationId);
    return volumeAutomation.length != initialLength;
  }

  /// Get the volume level at a specific beat position
  double getVolumeAtBeat(double beat) {
    if (volumeAutomation.isEmpty) {
      return volume;
    }

    // If before the first automation point, use the track volume
    if (beat < volumeAutomation.first.beat) {
      return volume;
    }

    // If after the last automation point, use its volume
    if (beat >= volumeAutomation.last.beat) {
      return volumeAutomation.last.volume;
    }

    // Find the automation points before and after the current beat
    VolumeAutomation? before;
    VolumeAutomation? after;

    for (int i = 0; i < volumeAutomation.length - 1; i++) {
      if (beat >= volumeAutomation[i].beat && beat < volumeAutomation[i + 1].beat) {
        before = volumeAutomation[i];
        after = volumeAutomation[i + 1];
        break;
      }
    }

    if (before != null && after != null) {
      // Interpolate between the two points
      final ratio = (beat - before.beat) / (after.beat - before.beat);
      return before.volume + (after.volume - before.volume) * ratio;
    }

    return volume;
  }

  @override
  String toString() {
    return 'Track(id: $id, instrumentId: $instrumentId, name: ${name ?? "unnamed"}, notes: ${notes.length}, volumeAutomation: ${volumeAutomation.length})';
  }
} 