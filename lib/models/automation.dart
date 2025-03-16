/// Represents a volume automation point in a sequence track
class VolumeAutomation {
  /// The unique ID of the automation point
  final int id;
  
  /// The beat position of the automation point
  final double beat;
  
  /// The volume value (0.0 to 1.0)
  final double volume;

  /// Creates a new VolumeAutomation instance
  const VolumeAutomation({
    required this.id,
    required this.beat,
    required this.volume,
  });

  @override
  String toString() {
    return 'VolumeAutomation(id: $id, beat: $beat, volume: $volume)';
  }
} 