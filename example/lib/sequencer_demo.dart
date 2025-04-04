import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_multitracker/flutter_multitracker.dart';

class SequencerDemo extends StatefulWidget {
  // Optional instrument IDs that can be passed from parent
  final int? drumInstrumentId;
  final int? melodyInstrumentId;

  const SequencerDemo({
    Key? key, 
    this.drumInstrumentId,
    this.melodyInstrumentId,
  }) : super(key: key);

  @override
  State<SequencerDemo> createState() => _SequencerDemoState();
}

class _SequencerDemoState extends State<SequencerDemo> with SingleTickerProviderStateMixin {
  // Multitracker instance
  final _multitracker = FlutterMultitracker();
  
  // Sequencer state
  Sequence? _sequence;
  List<Track> _tracks = [];
  Track? _selectedTrack;
  late Ticker _ticker;
  
  // Instrument objects
  Instrument? _drumInstrument;
  Instrument? _melodyInstrument;
  
  // Playback state
  double _tempo = 120.0;
  int _stepCount = 16;
  double _position = 0.0;
  bool _isPlaying = false;
  bool _isLooping = true;
  
  // Step sequencer state
  final Map<int, Map<int, Map<int, double>>> _trackStepVelocities = {};
  
  // Drum machine configuration
  final List<DrumPadConfig> _drumPads = [
    DrumPadConfig(name: 'Kick', noteNumber: 36, color: Colors.red),
    DrumPadConfig(name: 'Snare', noteNumber: 38, color: Colors.blue),
    DrumPadConfig(name: 'Closed HH', noteNumber: 42, color: Colors.green),
    DrumPadConfig(name: 'Open HH', noteNumber: 46, color: Colors.amber),
    DrumPadConfig(name: 'Low Tom', noteNumber: 41, color: Colors.purple),
    DrumPadConfig(name: 'Mid Tom', noteNumber: 45, color: Colors.teal),
    DrumPadConfig(name: 'High Tom', noteNumber: 48, color: Colors.indigo),
    DrumPadConfig(name: 'Clap', noteNumber: 39, color: Colors.pink),
    DrumPadConfig(name: 'Rim Shot', noteNumber: 37, color: Colors.lime),
    DrumPadConfig(name: 'Cowbell', noteNumber: 56, color: Colors.brown),
  ];

  @override
  void initState() {
    super.initState();
    
    // Get instruments from parent if provided
    if (widget.drumInstrumentId != null) {
      _drumInstrument = _multitracker.getInstrument(widget.drumInstrumentId!);
      debugPrint('Using drum instrument from parent: $_drumInstrument');
    }
    
    if (widget.melodyInstrumentId != null) {
      _melodyInstrument = _multitracker.getInstrument(widget.melodyInstrumentId!);
      debugPrint('Using melody instrument from parent: $_melodyInstrument');
    }
    
    _initSequencer();
    
    // Create a ticker to update UI
    _ticker = createTicker((elapsed) {
      if (_sequence != null) {
        _updatePosition();
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cleanup();
    super.dispose();
  }
  
  Future<void> _initSequencer() async {
    try {
      debugPrint('Initializing sequencer...');
      
      // Create a sequence
      final sequence = await _multitracker.createSequence(_tempo);
      
      if (sequence != null) {
        setState(() {
          _sequence = sequence;
        });
        
        debugPrint('Created sequence with ID: ${sequence.id}');
        
        // Create instruments and tracks
        await _createTracks();
      } else {
        debugPrint('Failed to create sequence');
      }
    } catch (e) {
      debugPrint('Error initializing sequencer: $e');
    }
  }
  
  Future<void> _createTracks() async {
    if (_sequence == null) return;
    
    try {
      debugPrint('Creating tracks for sequence ${_sequence!.id}...');
      
      // Create drum track
      await _createDrumTrack();
      
      // Create melody track
      await _createMelodyTrack();
      
      // Load a demo pattern
      if (_tracks.isNotEmpty && _selectedTrack != null) {
        await _loadDemoPattern();
      }
    } catch (e) {
      debugPrint('Error creating tracks: $e');
    }
  }
  
  Future<void> _createDrumTrack() async {
    // Skip if we already have a drum instrument from parent
    if (_drumInstrument == null) {
      // Try to load the TR-808 SF2 instrument
      try {
        debugPrint('Attempting to load TR-808 SF2 instrument...');
        // First try to load from SF2
        _drumInstrument = await _multitracker.loadSF2(
          'assets/sf2/TR-808.sf2',
          0,
          0,
          name: 'TR-808 Drums'
        );
        
        if (_drumInstrument != null) {
          debugPrint('Successfully loaded TR-808 SF2 instrument with ID: ${_drumInstrument!.id}');
        } else {
          debugPrint('Failed to load SF2 instrument, result was null');
        }
      } catch (e) {
        debugPrint('Error loading SF2 instrument: $e');
      }
      
      // Fallback to creating a sample-based instrument if SF2 loading failed
      if (_drumInstrument == null) {
        debugPrint('Creating SFZ drum instrument as fallback...');
        _drumInstrument = await _multitracker.loadSFZ('assets/sfz/drums.sfz', name: 'TR-808 Drums');
        
        if (_drumInstrument != null) {
          debugPrint('Created SFZ drum instrument with ID: ${_drumInstrument!.id}');
        } else {
          debugPrint('Failed to create SFZ drum instrument');
        }
      }
    } else {
      debugPrint('Using drum instrument from parent: $_drumInstrument');
    }
    
    // Create a track for drums if we have a drum instrument
    if (_drumInstrument != null && _sequence != null) {
      final drumTrack = await _multitracker.addTrack(_sequence!, _drumInstrument!);
      
      if (drumTrack != null) {
        debugPrint('Created drum track with ID: ${drumTrack.id}');
        
        // Initialize step velocities for drum track
        _trackStepVelocities[drumTrack.id] = {};
        
        for (final pad in _drumPads) {
          _trackStepVelocities[drumTrack.id]![pad.noteNumber] = {};
        }
        
        setState(() {
          _tracks.add(drumTrack);
          _selectedTrack = drumTrack;
        });
      } else {
        debugPrint('Failed to create drum track');
      }
    } else {
      debugPrint('No drum instrument available, skipping drum track creation');
    }
  }
  
  Future<void> _createMelodyTrack() async {
    // Skip if we already have a melody instrument from parent
    if (_melodyInstrument == null) {
      // Create a sine wave instrument (use SFZ with sine wave)
      debugPrint('Creating sine wave instrument for melody...');
      _melodyInstrument = await _multitracker.loadSFZ('assets/sfz/sine.sfz', name: 'Sine Wave');
      
      if (_melodyInstrument != null) {
        debugPrint('Created sine wave instrument with ID: ${_melodyInstrument!.id}');
      } else {
        debugPrint('Failed to create sine wave instrument');
      }
    } else {
      debugPrint('Using melody instrument from parent: $_melodyInstrument');
    }
    
    // Create a track for melody if we have a melody instrument
    if (_melodyInstrument != null && _sequence != null) {
      final melodyTrack = await _multitracker.addTrack(_sequence!, _melodyInstrument!);
      
      if (melodyTrack != null) {
        debugPrint('Created melody track with ID: ${melodyTrack.id}');
        
        // Initialize step velocities for melody track
        _trackStepVelocities[melodyTrack.id] = {};
        
        // Use C major scale notes
        final melodyNotes = [60, 62, 64, 65, 67, 69, 71, 72];
        
        for (final note in melodyNotes) {
          _trackStepVelocities[melodyTrack.id]![note] = {};
        }
        
        setState(() {
          _tracks.add(melodyTrack);
        });
      } else {
        debugPrint('Failed to create melody track');
      }
    } else {
      debugPrint('No melody instrument available, skipping melody track creation');
    }
  }
  
  Future<void> _updatePosition() async {
    if (_sequence != null) {
      try {
        final position = await _multitracker.getPlaybackPosition(_sequence!);
        
        // Check if sequence is playing by comparing consecutive positions
        final isPlaying = position > _position || (position < _position && _isLooping);
        
        setState(() {
          _position = position;
          _isPlaying = isPlaying;
        });
      } catch (e) {
        debugPrint('Error updating position: $e');
      }
    }
  }
  
  Future<void> _togglePlayPause() async {
    if (_sequence == null) return;
    
    try {
      if (_isPlaying) {
        await _multitracker.stopSequence(_sequence!);
      } else {
        await _multitracker.playSequence(_sequence!, loop: _isLooping);
      }
      
      setState(() {
        _isPlaying = !_isPlaying;
      });
    } catch (e) {
      debugPrint('Error toggling playback: $e');
    }
  }
  
  Future<void> _stop() async {
    if (_sequence == null) return;
    
    try {
      await _multitracker.stopSequence(_sequence!);
      await _multitracker.setPlaybackPosition(_sequence!, 0);
      
      setState(() {
        _isPlaying = false;
        _position = 0;
      });
    } catch (e) {
      debugPrint('Error stopping playback: $e');
    }
  }
  
  Future<void> _toggleLoop() async {
    if (_sequence == null) return;
    
    setState(() {
      _isLooping = !_isLooping;
    });
  }
  
  Future<void> _setTempo(double tempo) async {
    setState(() {
      _tempo = tempo;
    });
  }
  
  Future<void> _setStepCount(int count) async {
    if (_sequence == null || count < 1) return;
    
    setState(() {
      _stepCount = count;
    });
    
    // Update all tracks with new step count
    _syncAllTracks();
  }
  
  Future<void> _syncAllTracks() async {
    if (_sequence == null) return;
    
    for (final track in _tracks) {
      await _syncTrack(track);
    }
  }
  
  Future<void> _syncTrack(Track track) async {
    if (_sequence == null) return;
    
    try {
      // We need to recreate the sequence since our API doesn't support
      // updating existing sequences directly
      if (_sequence != null) {
        await _multitracker.stopSequence(_sequence!);
        
        // Create a new sequence with the same tempo
        final newSequence = await _multitracker.createSequence(_tempo);
        if (newSequence != null) {
          // Add all tracks to the new sequence
          final Map<int, Track> newTracks = {};
          
          for (final oldTrack in _tracks) {
            final instrument = _multitracker.getInstrument(oldTrack.instrumentId);
            if (instrument != null) {
              final newTrack = await _multitracker.addTrack(newSequence, instrument);
              if (newTrack != null) {
                newTracks[oldTrack.id] = newTrack;
              }
            }
          }
          
          // Add all notes from step velocities
          for (final oldTrackId in _trackStepVelocities.keys) {
            final newTrack = newTracks[oldTrackId];
            if (newTrack != null) {
              final stepVelocities = _trackStepVelocities[oldTrackId];
              if (stepVelocities != null) {
                for (final noteNumber in stepVelocities.keys) {
                  for (final step in stepVelocities[noteNumber]!.keys) {
                    if (step < _stepCount) {
                      final velocity = stepVelocities[noteNumber]![step]!;
                      
                      await _multitracker.addNote(
                        newTrack,
                        noteNumber,
                        (velocity * 127).toInt(),
                        step.toDouble(),
                        1.0, // Duration of 1 beat
                      );
                    }
                  }
                }
              }
            }
          }
          
          // Update the UI state
          setState(() {
            _sequence = newSequence;
            _tracks = newTracks.values.toList();
            _selectedTrack = _tracks.firstWhere(
              (t) => t.instrumentId == track.instrumentId,
              orElse: () => _tracks.isNotEmpty ? _tracks.first : track,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error syncing track: $e');
    }
  }
  
  void _toggleStep(int trackId, int noteNumber, int step) {
    if (_trackStepVelocities[trackId] == null ||
        _trackStepVelocities[trackId]![noteNumber] == null) {
      return;
    }
    
    setState(() {
      if (_trackStepVelocities[trackId]![noteNumber]!.containsKey(step)) {
        // Remove the note
        _trackStepVelocities[trackId]![noteNumber]!.remove(step);
      } else {
        // Add the note with default velocity
        _trackStepVelocities[trackId]![noteNumber]![step] = 0.8;
      }
    });
    
    // Find the track and sync it
    final track = _tracks.firstWhere((t) => t.id == trackId);
    _syncTrack(track);
  }
  
  Future<void> _loadDemoPattern() async {
    if (_selectedTrack == null || _sequence == null) return;
    
    final trackId = _selectedTrack!.id;
    
    try {
      // Clear current pattern
      for (final noteEntry in _trackStepVelocities[trackId]!.entries) {
        noteEntry.value.clear();
      }
      
      // Add a basic drum pattern
      if (_tracks.indexOf(_selectedTrack!) == 0) { // Drum track
        // Kick on beats 0, 4, 8, 12
        _trackStepVelocities[trackId]![36]![0] = 1.0;
        _trackStepVelocities[trackId]![36]![4] = 1.0;
        _trackStepVelocities[trackId]![36]![8] = 1.0;
        _trackStepVelocities[trackId]![36]![12] = 1.0;
        
        // Snare on beats 4 and 12
        _trackStepVelocities[trackId]![38]![4] = 0.8;
        _trackStepVelocities[trackId]![38]![12] = 0.8;
        
        // Hi-hat on even beats
        for (int i = 0; i < _stepCount; i += 2) {
          _trackStepVelocities[trackId]![42]![i] = 0.6;
        }
        
        // Open hi-hat on some odd beats
        _trackStepVelocities[trackId]![46]![3] = 0.7;
        _trackStepVelocities[trackId]![46]![7] = 0.7;
        _trackStepVelocities[trackId]![46]![11] = 0.7;
        _trackStepVelocities[trackId]![46]![15] = 0.7;
        
        // Clap reinforcing snare
        _trackStepVelocities[trackId]![39]![4] = 0.5;
        _trackStepVelocities[trackId]![39]![12] = 0.5;
        
        // Cowbell accent
        _trackStepVelocities[trackId]![56]![7] = 0.6;
        _trackStepVelocities[trackId]![56]![15] = 0.6;
      } else { // Melody track
        // Simple C major arpeggio
        _trackStepVelocities[trackId]![60]![0] = 0.8;
        _trackStepVelocities[trackId]![64]![4] = 0.8;
        _trackStepVelocities[trackId]![67]![8] = 0.8;
        _trackStepVelocities[trackId]![72]![12] = 0.8;
      }
      
      // Update the track
      await _syncTrack(_selectedTrack!);
      
      setState(() {});
    } catch (e) {
      debugPrint('Error loading demo pattern: $e');
    }
  }
  
  Future<void> _clearPattern() async {
    if (_selectedTrack == null || _sequence == null) return;
    
    final trackId = _selectedTrack!.id;
    
    try {
      // Clear current pattern
      for (final noteEntry in _trackStepVelocities[trackId]!.entries) {
        noteEntry.value.clear();
      }
      
      // Update the track
      await _syncTrack(_selectedTrack!);
      
      setState(() {});
    } catch (e) {
      debugPrint('Error clearing pattern: $e');
    }
  }
  
  Future<void> _cleanup() async {
    if (_sequence != null) {
      try {
        await _multitracker.stopSequence(_sequence!);
        await _multitracker.dispose();
      } catch (e) {
        debugPrint('Error cleaning up sequence: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Transport controls
          _buildTransportControls(),
          
          // Tempo and step count controls
          _buildTempoAndStepControls(),
          
          // Track selector
          _buildTrackSelector(),
          
          // Step sequencer grid
          Expanded(
            child: _buildStepSequencer(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransportControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 36,
            onPressed: _togglePlayPause,
          ),
          
          // Stop button
          IconButton(
            icon: const Icon(Icons.stop),
            iconSize: 36,
            onPressed: _stop,
          ),
          
          // Loop button
          IconButton(
            icon: Icon(_isLooping ? Icons.repeat_one : Icons.repeat),
            iconSize: 36,
            color: _isLooping ? Colors.blue : null,
            onPressed: _toggleLoop,
          ),
          
          // Position indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Beat: ${_position.toStringAsFixed(1)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTempoAndStepControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Tempo control
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tempo (BPM):'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _tempo,
                        min: 60,
                        max: 200,
                        divisions: 140,
                        label: _tempo.round().toString(),
                        onChanged: (value) {
                          _setTempo(value);
                        },
                      ),
                    ),
                    Text(
                      _tempo.round().toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),
          
          // Step count control
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Steps:'),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_stepCount > 4) {
                        _setStepCount(_stepCount - 4);
                      }
                    },
                  ),
                  Text(
                    _stepCount.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_stepCount < 32) {
                        _setStepCount(_stepCount + 4);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrackSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _tracks.length,
          itemBuilder: (context, index) {
            final track = _tracks[index];
            final isSelected = _selectedTrack?.id == track.id;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue : null,
                  foregroundColor: isSelected ? Colors.white : null,
                ),
                onPressed: () {
                  setState(() {
                    _selectedTrack = track;
                  });
                },
                child: Text(track.name ?? 'Track ${track.id}'),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildStepSequencer() {
    if (_selectedTrack == null) {
      return const Center(
        child: Text('No track selected'),
      );
    }
    
    final trackId = _selectedTrack!.id;
    final stepVelocities = _trackStepVelocities[trackId];
    
    if (stepVelocities == null || stepVelocities.isEmpty) {
      return const Center(
        child: Text('No notes available for this track'),
      );
    }
    
    // Sort note numbers in descending order (higher notes at the top)
    final noteNumbers = stepVelocities.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          // Header with step numbers
          Row(
            children: [
              // Note labels column
              SizedBox(
                width: 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  alignment: Alignment.center,
                  child: const Text(
                    'Notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // Step numbers
              Expanded(
                child: Row(
                  children: List.generate(_stepCount, (step) {
                    final isCurrentStep = _position.floor() == step;
                    
                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[700]!,
                              width: 1.0,
                            ),
                          ),
                          color: isCurrentStep ? Colors.blue.withOpacity(0.3) : null,
                        ),
                        child: Text(
                          (step + 1).toString(),
                          style: TextStyle(
                            color: isCurrentStep ? Colors.blue : Colors.white,
                            fontWeight: isCurrentStep ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          
          // Grid with notes and steps
          Expanded(
            child: ListView.builder(
              itemCount: noteNumbers.length,
              itemBuilder: (context, rowIndex) {
                final noteNumber = noteNumbers[rowIndex];
                final noteName = _getNoteNameForTrack(trackId, noteNumber);
                
                return Row(
                  children: [
                    // Note label
                    SizedBox(
                      width: 80,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          noteName,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    
                    // Step cells
                    Expanded(
                      child: Row(
                        children: List.generate(_stepCount, (step) {
                          final isActive = stepVelocities[noteNumber]!.containsKey(step);
                          final isCurrentStep = _position.floor() == step;
                          
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _toggleStep(trackId, noteNumber, step),
                              child: Container(
                                margin: const EdgeInsets.all(2.0),
                                decoration: BoxDecoration(
                                  color: isActive 
                                    ? _getColorForNote(trackId, noteNumber) 
                                    : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: isCurrentStep 
                                    ? Border.all(color: Colors.white, width: 2.0) 
                                    : null,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  String _getNoteNameForTrack(int trackId, int noteNumber) {
    // For drum tracks, return the drum name
    if (_selectedTrack?.name == 'Drums') {
      final drumPad = _drumPads.firstWhere(
        (pad) => pad.noteNumber == noteNumber,
        orElse: () => DrumPadConfig(name: 'Note $noteNumber', noteNumber: noteNumber, color: Colors.grey),
      );
      return drumPad.name;
    }
    
    // For other tracks, return the note name
    final note = noteNumber % 12;
    final octave = (noteNumber / 12).floor() - 1;
    
    final noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return '${noteNames[note]}$octave';
  }
  
  Color _getColorForNote(int trackId, int noteNumber) {
    // For drum tracks, return the drum color
    if (_selectedTrack?.name == 'Drums') {
      final drumPad = _drumPads.firstWhere(
        (pad) => pad.noteNumber == noteNumber,
        orElse: () => DrumPadConfig(name: 'Note $noteNumber', noteNumber: noteNumber, color: Colors.grey),
      );
      return drumPad.color;
    }
    
    // For other tracks, return a color based on the note number
    final hue = (noteNumber % 12) * 30.0;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.8).toColor();
  }
}

class DrumPadConfig {
  final String name;
  final int noteNumber;
  final Color color;
  
  DrumPadConfig({
    required this.name,
    required this.noteNumber,
    required this.color,
  });
} 