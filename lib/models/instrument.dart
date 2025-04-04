/// Enum defining the type of instrument
enum InstrumentType {
  /// SFZ format sampler instrument
  sfz,
  
  /// SoundFont (SF2) format sampler instrument
  sf2,
  
  /// iOS only: AudioUnit instrument
  audioUnit,
}

/// Represents a loaded instrument in the sequencer
class Instrument {
  /// The unique ID assigned by the native implementation
  final int id;
  
  /// The type of instrument
  final InstrumentType type;
  
  /// The path to the instrument file (SFZ, SF2) or component description (AudioUnit)
  final String? path;
  
  /// The name of the instrument (if available)
  final String name;
  
  /// For SF2 instruments, the preset number
  final int? preset;
  
  /// For SF2 instruments, the bank number
  final int? bank;

  /// Creates a new Instrument instance
  const Instrument({
    required this.id,
    required this.type,
    required this.name,
    this.path,
    this.preset,
    this.bank,
  });

  @override
  String toString() {
    return 'Instrument(id: $id, type: $type, name: $name)';
  }
} 