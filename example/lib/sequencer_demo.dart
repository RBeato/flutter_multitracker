import 'package:flutter/material.dart';
import 'package:flutter_multitracker/flutter_multitracker.dart';

class SequencerDemo extends StatefulWidget {
  const SequencerDemo({Key? key}) : super(key: key);

  @override
  State<SequencerDemo> createState() => _SequencerDemoState();
}

class _SequencerDemoState extends State<SequencerDemo> {
  final FlutterMultitracker _multitracker = FlutterMultitracker();
  
  Sequence? _sequence;
  List<Track> _tracks = [];
  Instrument? _pianoInstrument;
  Instrument? _bassInstrument;
  Instrument? _drumInstrument;
  
  bool _isInitialized = false;
  bool _isPlaying = false;
  double _tempo = 120.0;
  double _position = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeSequencer();
  }
  
  Future<void> _initializeSequencer() async {
    // Initialize the audio engine
    final initialized = await _multitracker.initialize();
    if (!initialized) {
      debugPrint('Failed to initialize audio engine');
      return;
    }
    
    // Create instruments
    _pianoInstrument = await _multitracker.createInstrument('Piano', 'sine');
    _bassInstrument = await _multitracker.createInstrument('Bass', 'sine');
    _drumInstrument = await _multitracker.createInstrument('Drums', 'noise');
    
    if (_pianoInstrument == null || _bassInstrument == null || _drumInstrument == null) {
      debugPrint('Failed to create instruments');
      return;
    }
    
    // Set instrument parameters
    await _multitracker.setInstrumentEnvelope(_pianoInstrument!.id, 0.01, 0.1, 0.7, 0.3);
    await _multitracker.setInstrumentEnvelope(_bassInstrument!.id, 0.05, 0.2, 0.8, 0.5);
    await _multitracker.setInstrumentEnvelope(_drumInstrument!.id, 0.001, 0.1, 0.0, 0.1);
    
    // Create a sequence
    _sequence = await _multitracker.createSequence(_tempo);
    if (_sequence == null) {
      debugPrint('Failed to create sequence');
      return;
    }
    
    // Create tracks
    final pianoTrack = await _multitracker.addTrack(_sequence!.id, _pianoInstrument!.id, 'Piano');
    final bassTrack = await _multitracker.addTrack(_sequence!.id, _bassInstrument!.id, 'Bass');
    final drumTrack = await _multitracker.addTrack(_sequence!.id, _drumInstrument!.id, 'Drums');
    
    if (pianoTrack == null || bassTrack == null || drumTrack == null) {
      debugPrint('Failed to create tracks');
      return;
    }
    
    _tracks = [pianoTrack, bassTrack, drumTrack];
    
    // Add piano notes (simple C major chord arpeggio)
    await _multitracker.addNote(_sequence!.id, pianoTrack.id, 60, 100, 0.0, 0.5); // C4
    await _multitracker.addNote(_sequence!.id, pianoTrack.id, 64, 100, 1.0, 0.5); // E4
    await _multitracker.addNote(_sequence!.id, pianoTrack.id, 67, 100, 2.0, 0.5); // G4
    await _multitracker.addNote(_sequence!.id, pianoTrack.id, 72, 100, 3.0, 0.5); // C5
    
    // Add bass notes (simple bass line)
    await _multitracker.addNote(_sequence!.id, bassTrack.id, 36, 100, 0.0, 1.0); // C2
    await _multitracker.addNote(_sequence!.id, bassTrack.id, 43, 100, 2.0, 1.0); // G2
    
    // Add drum notes (simple kick and snare pattern)
    await _multitracker.addNote(_sequence!.id, drumTrack.id, 36, 100, 0.0, 0.1); // Kick
    await _multitracker.addNote(_sequence!.id, drumTrack.id, 38, 80, 1.0, 0.1);  // Snare
    await _multitracker.addNote(_sequence!.id, drumTrack.id, 36, 100, 2.0, 0.1); // Kick
    await _multitracker.addNote(_sequence!.id, drumTrack.id, 38, 80, 3.0, 0.1);  // Snare
    
    // Set up loop
    await _multitracker.setLoop(_sequence!.id, 0.0, 4.0);
    
    // Start position update timer
    _startPositionTimer();
    
    setState(() {
      _isInitialized = true;
    });
  }
  
  void _startPositionTimer() {
    Future.delayed(const Duration(milliseconds: 100), () async {
      if (_sequence != null) {
        final position = await _multitracker.getPosition(_sequence!.id);
        final isPlaying = await _multitracker.getIsPlaying(_sequence!.id);
        
        setState(() {
          _position = position;
          _isPlaying = isPlaying;
        });
      }
      
      if (mounted) {
        _startPositionTimer();
      }
    });
  }
  
  Future<void> _togglePlayback() async {
    if (_sequence == null) return;
    
    if (_isPlaying) {
      await _multitracker.stopPlayback(_sequence!.id);
    } else {
      await _multitracker.startPlayback(_sequence!.id);
    }
    
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }
  
  Future<void> _setTempo(double tempo) async {
    if (_sequence == null) return;
    
    await _multitracker.setTempo(_sequence!.id, tempo);
    
    setState(() {
      _tempo = tempo;
    });
  }
  
  Future<void> _setTrackVolume(int trackIndex, double volume) async {
    if (_sequence == null || trackIndex >= _tracks.length) return;
    
    final track = _tracks[trackIndex];
    await _multitracker.setTrackVolume(_sequence!.id, track.id, volume);
    
    setState(() {
      _tracks[trackIndex].volume = volume;
    });
  }
  
  Future<void> _toggleTrackMute(int trackIndex) async {
    if (_sequence == null || trackIndex >= _tracks.length) return;
    
    final track = _tracks[trackIndex];
    final newMuteState = !track.muted;
    
    await _multitracker.setTrackMuted(_sequence!.id, track.id, newMuteState);
    
    setState(() {
      _tracks[trackIndex].muted = newMuteState;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequencer Demo'),
      ),
      body: _isInitialized
          ? Column(
              children: [
                // Transport controls
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                        iconSize: 48,
                        onPressed: _togglePlayback,
                      ),
                      const SizedBox(width: 24),
                      Column(
                        children: [
                          Text('Tempo: ${_tempo.toStringAsFixed(1)} BPM'),
                          Slider(
                            value: _tempo,
                            min: 60,
                            max: 180,
                            divisions: 120,
                            label: _tempo.round().toString(),
                            onChanged: _setTempo,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Position indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Text('Position: ${_position.toStringAsFixed(2)} beats'),
                      LinearProgressIndicator(
                        value: (_position % 4.0) / 4.0,
                        minHeight: 10,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Track controls
                Expanded(
                  child: ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    track.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(track.muted ? Icons.volume_off : Icons.volume_up),
                                    onPressed: () => _toggleTrackMute(index),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text('Volume:'),
                                  Expanded(
                                    child: Slider(
                                      value: track.volume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (value) => _setTrackVolume(index, value),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing sequencer...'),
                ],
              ),
            ),
    );
  }
  
  @override
  void dispose() {
    if (_sequence != null) {
      _multitracker.stopPlayback(_sequence!.id);
    }
    _multitracker.cleanup();
    super.dispose();
  }
} 