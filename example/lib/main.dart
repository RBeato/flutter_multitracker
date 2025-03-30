import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multitracker/flutter_multitracker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'sequencer_demo.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _status = 'Not initialized';
  bool _isInitialized = false;
  bool _isPlaying = false;
  double _masterVolume = 0.8;
  int _instrumentId = 0;
  int _sampleInstrumentId = -1;
  int _drumInstrumentId = -1;
  
  // Instrument type selection
  String _selectedInstrumentType = 'Sine Wave';
  final List<String> _instrumentTypes = ['Sine Wave', 'Piano Samples', 'TR-808 Drums'];
  
  // ADSR envelope parameters
  double _attack = 0.01;
  double _decay = 0.05;
  double _sustain = 0.7;
  double _release = 0.3;

  // Piano keyboard state
  final Map<int, bool> _activeNotes = {};
  
  // Create an instance of the plugin
  final _multitracker = FlutterMultitracker();
  
  // Current demo page
  int _currentPage = 0;
  
  // Drum pad configuration
  final List<DrumPad> _drumPads = [
    DrumPad(name: 'Kick', noteNumber: 36, color: Colors.red),
    DrumPad(name: 'Snare', noteNumber: 38, color: Colors.blue),
    DrumPad(name: 'Closed HH', noteNumber: 42, color: Colors.green),
    DrumPad(name: 'Open HH', noteNumber: 46, color: Colors.amber),
    DrumPad(name: 'Low Tom', noteNumber: 41, color: Colors.purple),
    DrumPad(name: 'Mid Tom', noteNumber: 45, color: Colors.teal),
    DrumPad(name: 'High Tom', noteNumber: 48, color: Colors.indigo),
    DrumPad(name: 'Crash', noteNumber: 49, color: Colors.orange),
    DrumPad(name: 'Ride', noteNumber: 51, color: Colors.cyan),
    DrumPad(name: 'Clap', noteNumber: 39, color: Colors.pink),
    DrumPad(name: 'Rim Shot', noteNumber: 37, color: Colors.lime),
    DrumPad(name: 'Cowbell', noteNumber: 56, color: Colors.brown),
    DrumPad(name: 'Maracas', noteNumber: 70, color: Colors.deepOrange),
    DrumPad(name: 'Conga', noteNumber: 63, color: Colors.lightBlue),
    DrumPad(name: 'Clave', noteNumber: 75, color: Colors.amber[700]!),
    DrumPad(name: 'Tambourine', noteNumber: 54, color: Colors.deepPurple),
  ];

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    // Clean up resources when the app is closed
    _cleanup();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await FlutterMultitracker.platformVersion ?? 'Unknown platform version';
      
      // Initialize the audio engine
      _isInitialized = await _multitracker.initialize();
      
      if (_isInitialized) {
        // Create default sine wave instrument
        _instrumentId = 0; // Default instrument created by the native code
        
        // Create sample-based instruments
        await _createSampleInstruments();
      }
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }
  
  Future<void> _createSampleInstruments() async {
    try {
      debugPrint('Creating sample instruments...');
      
      // Create a piano instrument using WAV samples
      final pianoInstrument = await _multitracker.createInstrument('Piano Samples', 'sample');
      
      if (pianoInstrument != null) {
        _sampleInstrumentId = pianoInstrument.id;
        debugPrint('Created piano instrument with ID: $_sampleInstrumentId');
        
        // Set envelope parameters
        await _multitracker.setInstrumentEnvelope(
          _sampleInstrumentId,
          0.01,
          0.1,
          0.7,
          0.3,
        );
        
        // Extract WAV files to temporary directory
        final tempDir = await getTemporaryDirectory();
        
        // Define sample paths
        final Map<int, String> pianoSamples = {
          60: 'assets/wav/D3.wav',    // Middle C (C4)
          65: 'assets/wav/F3.wav',    // F4
          67: 'assets/wav/Gsharp3.wav', // G4
        };
        
        // Load each sample
        for (final entry in pianoSamples.entries) {
          final noteNumber = entry.key;
          final assetPath = entry.value;
          
          try {
            // Load the asset
            final ByteData data = await rootBundle.load(assetPath);
            final List<int> bytes = data.buffer.asUint8List();
            
            // Create a temporary file
            final filename = assetPath.split('/').last;
            final filePath = '${tempDir.path}/$filename';
            final file = File(filePath);
            await file.writeAsBytes(bytes);
            
            // Load the sample into the instrument
            await _multitracker.loadSample(
              instrumentId: _sampleInstrumentId,
              noteNumber: noteNumber,
              assetPath: assetPath,
            );
            
            debugPrint('Loaded sample for note $noteNumber: $assetPath');
          } catch (e) {
            debugPrint('Error loading sample $assetPath: $e');
          }
        }
        
        debugPrint('Finished loading piano samples');
      } else {
        debugPrint('Failed to create piano instrument');
      }
      
      // Try to load the TR-808 SF2 instrument
      try {
        debugPrint('Attempting to load TR-808 SF2 instrument...');
        
        final sf2Instrument = await _multitracker.loadInstrumentFromSF2(
          sf2Path: 'assets/sf2/TR-808.sf2',
          isAsset: true,
          preset: 0,
          bank: 0,
        );
        
        if (sf2Instrument != null) {
          _drumInstrumentId = sf2Instrument.id;
          debugPrint('Successfully loaded TR-808 SF2 instrument with ID: $_drumInstrumentId');
          
          // Set envelope parameters for drums (very short for percussive sounds)
          await _multitracker.setInstrumentEnvelope(
            _drumInstrumentId,
            0.001,  // Very short attack
            0.01,   // Short decay
            0.3,    // Lower sustain level
            0.05,   // Very short release
          );
          
          debugPrint('Set envelope parameters for TR-808 instrument');
        } else {
          debugPrint('Failed to load SF2 instrument, result was null');
          // Fallback to sample-based drum instrument
          await _createSampleBasedDrumInstrument();
        }
      } catch (e) {
        debugPrint('Error loading SF2 instrument: $e');
        // Fallback to sample-based drum instrument
        await _createSampleBasedDrumInstrument();
      }
      
    } catch (e) {
      debugPrint('Error creating sample instruments: $e');
    }
  }
  
  Future<void> _createSampleBasedDrumInstrument() async {
    debugPrint('Creating sample-based drum instrument as fallback...');
    
    // Create a drum instrument
    final drumInstrument = await _multitracker.createInstrument('TR-808 Drums', 'sample');
    
    if (drumInstrument != null) {
      _drumInstrumentId = drumInstrument.id;
      debugPrint('Created sample-based drum instrument with ID: $_drumInstrumentId');
      
      // Set envelope parameters for drums (shorter release)
      await _multitracker.setInstrumentEnvelope(
        _drumInstrumentId,
        0.001,  // Very short attack
        0.01,   // Short decay
        0.3,    // Lower sustain level
        0.05,   // Very short release
      );
      
      debugPrint('Set envelope parameters for sample-based drum instrument');
    } else {
      debugPrint('Failed to create sample-based drum instrument');
    }
  }
  
  Future<void> _cleanup() async {
    if (_isInitialized) {
      // Stop all active notes
      for (final noteNumber in _activeNotes.keys.toList()) {
        if (_activeNotes[noteNumber] == true) {
          await _multitracker.noteOff(_getActiveInstrumentId(), noteNumber);
        }
      }
      
      // Clean up resources
      await _multitracker.cleanup();
    }
  }
  
  int _getActiveInstrumentId() {
    switch (_selectedInstrumentType) {
      case 'Piano Samples':
        return _sampleInstrumentId >= 0 ? _sampleInstrumentId : _instrumentId;
      case 'TR-808 Drums':
        return _drumInstrumentId >= 0 ? _drumInstrumentId : _instrumentId;
      case 'Sine Wave':
      default:
        return _instrumentId;
    }
  }
  
  Future<void> _playNote(int noteNumber) async {
    if (_isInitialized) {
      final int instrumentId = _getActiveInstrumentId();
      if (instrumentId >= 0) {
        await _multitracker.noteOn(instrumentId, noteNumber, 100);
        
        setState(() {
          _activeNotes[noteNumber] = true;
        });
      }
    }
  }
  
  Future<void> _stopNote(int noteNumber) async {
    if (_isInitialized) {
      final int instrumentId = _getActiveInstrumentId();
      if (instrumentId >= 0) {
        await _multitracker.noteOff(instrumentId, noteNumber);
        
        setState(() {
          _activeNotes[noteNumber] = false;
        });
      }
    }
  }
  
  Future<void> _playDrumPad(int noteNumber) async {
    if (_isInitialized && _drumInstrumentId >= 0) {
      await _multitracker.noteOn(_drumInstrumentId, noteNumber, 100);
      
      // No need to track active notes for drums as they have short envelopes
    }
  }
  
  Future<void> _setMasterVolume(double volume) async {
    if (_isInitialized) {
      await _multitracker.setMasterVolume(volume);
      
      setState(() {
        _masterVolume = volume;
      });
    }
  }

  void _updateEnvelope(double attack, double decay, double sustain, double release) {
    setState(() {
      _attack = attack;
      _decay = decay;
      _sustain = sustain;
      _release = release;
    });
    
    final int instrumentId = _getActiveInstrumentId();
    _multitracker.setInstrumentEnvelope(
      instrumentId,
      _attack,
      _decay,
      _sustain,
      _release,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: _isInitialized 
        ? MainScreen(
            platformVersion: _platformVersion,
            multitracker: _multitracker,
            instrumentId: _instrumentId,
            sampleInstrumentId: _sampleInstrumentId,
            drumInstrumentId: _drumInstrumentId,
            masterVolume: _masterVolume,
            attack: _attack,
            decay: _decay,
            sustain: _sustain,
            release: _release,
            onMasterVolumeChanged: _setMasterVolume,
            onEnvelopeChanged: _updateEnvelope,
          )
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing audio engine...'),
              ],
            ),
          ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String platformVersion;
  final FlutterMultitracker multitracker;
  final int instrumentId;
  final int sampleInstrumentId;
  final int drumInstrumentId;
  final double masterVolume;
  final double attack;
  final double decay;
  final double sustain;
  final double release;
  final Function(double) onMasterVolumeChanged;
  final Function(double, double, double, double) onEnvelopeChanged;

  const MainScreen({
    Key? key,
    required this.platformVersion,
    required this.multitracker,
    required this.instrumentId,
    required this.sampleInstrumentId,
    required this.drumInstrumentId,
    required this.masterVolume,
    required this.attack,
    required this.decay,
    required this.sustain,
    required this.release,
    required this.onMasterVolumeChanged,
    required this.onEnvelopeChanged,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _selectedInstrumentType = 'Sine Wave';
  final List<String> _instrumentTypes = ['Sine Wave', 'Piano Samples', 'TR-808 Drums'];
  
  // Local copies of envelope parameters that can be modified
  late double _attack;
  late double _decay;
  late double _sustain;
  late double _release;
  
  @override
  void initState() {
    super.initState();
    // Initialize local copies of envelope parameters
    _attack = widget.attack;
    _decay = widget.decay;
    _sustain = widget.sustain;
    _release = widget.release;
  }
  
  // Piano keyboard state
  final Map<int, bool> _activeNotes = {};
  
  // Drum pad configuration
  final List<DrumPad> _drumPads = [
    DrumPad(name: 'Kick', noteNumber: 36, color: Colors.red),
    DrumPad(name: 'Snare', noteNumber: 38, color: Colors.blue),
    DrumPad(name: 'Closed HH', noteNumber: 42, color: Colors.green),
    DrumPad(name: 'Open HH', noteNumber: 46, color: Colors.amber),
    DrumPad(name: 'Low Tom', noteNumber: 41, color: Colors.purple),
    DrumPad(name: 'Mid Tom', noteNumber: 45, color: Colors.teal),
    DrumPad(name: 'High Tom', noteNumber: 48, color: Colors.indigo),
    DrumPad(name: 'Crash', noteNumber: 49, color: Colors.orange),
    DrumPad(name: 'Ride', noteNumber: 51, color: Colors.cyan),
    DrumPad(name: 'Clap', noteNumber: 39, color: Colors.pink),
    DrumPad(name: 'Rim Shot', noteNumber: 37, color: Colors.lime),
    DrumPad(name: 'Cowbell', noteNumber: 56, color: Colors.brown),
    DrumPad(name: 'Maracas', noteNumber: 70, color: Colors.deepOrange),
    DrumPad(name: 'Conga', noteNumber: 63, color: Colors.lightBlue),
    DrumPad(name: 'Clave', noteNumber: 75, color: Colors.amber[700]!),
    DrumPad(name: 'Tambourine', noteNumber: 54, color: Colors.deepPurple),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
      ),
      body: _getPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Set appropriate instrument type based on page
            if (index == 0) {
              _selectedInstrumentType = 'Sine Wave';
            } else if (index == 1) {
              _selectedInstrumentType = 'TR-808 Drums';
            }
            // For sequencer, we don't change the instrument type as it manages its own instruments
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.piano),
            label: 'Piano',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Drums',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_music),
            label: 'Sequencer',
          ),
        ],
      ),
    );
  }
  
  String _getPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Piano Demo - $_selectedInstrumentType';
      case 1:
        return 'TR-808 Drum Machine';
      case 2:
        return 'Step Sequencer';
      default:
        return 'Flutter Multitracker';
    }
  }
  
  Widget _getPage() {
    switch (_currentIndex) {
      case 0:
        return _buildPianoDemo();
      case 1:
        return _buildDrumPads();
      case 2:
        return SequencerDemo(
          key: UniqueKey(),
          drumInstrumentId: widget.drumInstrumentId,
          melodyInstrumentId: widget.instrumentId, // Use the sine wave instrument for melody
        );
      default:
        return const Center(child: Text('Unknown page'));
    }
  }
  
  int _getActiveInstrumentId() {
    switch (_selectedInstrumentType) {
      case 'Piano Samples':
        return widget.sampleInstrumentId >= 0 ? widget.sampleInstrumentId : widget.instrumentId;
      case 'TR-808 Drums':
        return widget.drumInstrumentId >= 0 ? widget.drumInstrumentId : widget.instrumentId;
      case 'Sine Wave':
      default:
        return widget.instrumentId;
    }
  }
  
  Future<void> _playNote(int noteNumber) async {
    final int instrumentId = _getActiveInstrumentId();
    if (instrumentId >= 0) {
      await widget.multitracker.noteOn(instrumentId, noteNumber, 100);
      
      setState(() {
        _activeNotes[noteNumber] = true;
      });
    }
  }
  
  Future<void> _stopNote(int noteNumber) async {
    final int instrumentId = _getActiveInstrumentId();
    if (instrumentId >= 0) {
      await widget.multitracker.noteOff(instrumentId, noteNumber);
      
      setState(() {
        _activeNotes[noteNumber] = false;
      });
    }
  }
  
  Future<void> _playDrumPad(int noteNumber) async {
    // Always use the drum instrument ID for drum pads, regardless of selected instrument type
    if (widget.drumInstrumentId >= 0) {
      await widget.multitracker.noteOn(widget.drumInstrumentId, noteNumber, 100);
      
      // Debug print to verify the correct instrument is being used
      debugPrint('Playing drum pad with instrument ID: ${widget.drumInstrumentId}, note: $noteNumber');
    } else {
      debugPrint('Error: Drum instrument ID is not valid: ${widget.drumInstrumentId}');
    }
  }
  
  Widget _buildPianoDemo() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Running on: ${widget.platformVersion}'),
        ),
        
        // Instrument type selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text('Instrument Type:'),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedInstrumentType,
                  isExpanded: true,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedInstrumentType = newValue;
                      });
                    }
                  },
                  items: _instrumentTypes
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        
        // Master volume control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text('Master Volume:'),
              Expanded(
                child: Slider(
                  value: widget.masterVolume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    setState(() {
                      widget.onMasterVolumeChanged(value);
                    });
                  },
                ),
              ),
              Text('${(widget.masterVolume * 100).toInt()}%'),
            ],
          ),
        ),
        
        // ADSR envelope controls
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Envelope Controls:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        
        // Attack
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const SizedBox(width: 80, child: Text('Attack:')),
              Expanded(
                child: Slider(
                  value: _attack,
                  min: 0.001,
                  max: 2.0,
                  onChanged: (value) {
                    setState(() {
                      _attack = value;
                      _updateEnvelope();
                    });
                  },
                ),
              ),
              SizedBox(width: 60, child: Text('${_attack.toStringAsFixed(2)}s')),
            ],
          ),
        ),
        
        // Decay
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const SizedBox(width: 80, child: Text('Decay:')),
              Expanded(
                child: Slider(
                  value: _decay,
                  min: 0.001,
                  max: 2.0,
                  onChanged: (value) {
                    setState(() {
                      _decay = value;
                      _updateEnvelope();
                    });
                  },
                ),
              ),
              SizedBox(width: 60, child: Text('${_decay.toStringAsFixed(2)}s')),
            ],
          ),
        ),
        
        // Sustain
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const SizedBox(width: 80, child: Text('Sustain:')),
              Expanded(
                child: Slider(
                  value: _sustain,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    setState(() {
                      _sustain = value;
                      _updateEnvelope();
                    });
                  },
                ),
              ),
              SizedBox(width: 60, child: Text('${(_sustain * 100).toInt()}%')),
            ],
          ),
        ),
        
        // Release
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const SizedBox(width: 80, child: Text('Release:')),
              Expanded(
                child: Slider(
                  value: _release,
                  min: 0.001,
                  max: 3.0,
                  onChanged: (value) {
                    setState(() {
                      _release = value;
                      _updateEnvelope();
                    });
                  },
                ),
              ),
              SizedBox(width: 60, child: Text('${_release.toStringAsFixed(2)}s')),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Piano keyboard
        Expanded(
          child: ImprovedPianoKeyboard(
            onNoteOn: (noteNumber, velocity) {
              final int instrumentId = _getActiveInstrumentId();
              widget.multitracker.noteOn(instrumentId, noteNumber, velocity);
              setState(() {
                _activeNotes[noteNumber] = true;
              });
            },
            onNoteOff: (noteNumber) {
              final int instrumentId = _getActiveInstrumentId();
              widget.multitracker.noteOff(instrumentId, noteNumber);
              setState(() {
                _activeNotes[noteNumber] = false;
              });
            },
            activeNotes: _activeNotes,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDrumPads() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('TR-808 Drum Machine', 
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
        ),
        
        // Master volume control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Row(
              children: [
                const Text('Master Volume:', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: widget.masterVolume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.red[700],
                    inactiveColor: Colors.grey[400],
                    onChanged: (value) {
                      setState(() {
                        widget.onMasterVolumeChanged(value);
                      });
                    },
                  ),
                ),
                Text('${(widget.masterVolume * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Drum pads grid
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _drumPads.length,
              itemBuilder: (context, index) {
                final pad = _drumPads[index];
                return TR808DrumPad(
                  name: pad.name,
                  color: pad.color,
                  onTap: () => _playDrumPad(pad.noteNumber),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  
  void _updateEnvelope() {
    widget.onEnvelopeChanged(_attack, _decay, _sustain, _release);
  }
}

class DrumPad {
  final String name;
  final int noteNumber;
  final Color color;
  
  DrumPad({required this.name, required this.noteNumber, required this.color});
}

class DrumPadWidget extends StatefulWidget {
  final String name;
  final Color color;
  final VoidCallback onTap;
  
  const DrumPadWidget({
    Key? key,
    required this.name,
    required this.color,
    required this.onTap,
  }) : super(key: key);
  
  @override
  State<DrumPadWidget> createState() => _DrumPadWidgetState();
}

class _DrumPadWidgetState extends State<DrumPadWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
    widget.onTap();
  }
  
  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
  }
  
  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: Color.lerp(widget.color, Colors.white, _controller.value),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, _isPressed ? 1 : 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TR808DrumPad extends StatefulWidget {
  final String name;
  final Color color;
  final VoidCallback onTap;
  
  const TR808DrumPad({
    Key? key,
    required this.name,
    required this.color,
    required this.onTap,
  }) : super(key: key);
  
  @override
  State<TR808DrumPad> createState() => _TR808DrumPadState();
}

class _TR808DrumPadState extends State<TR808DrumPad> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
    widget.onTap();
  }
  
  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
  }
  
  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[800]!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, _isPressed ? 1 : 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LED indicator
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPressed 
                      ? widget.color 
                      : Colors.grey[800],
                    boxShadow: _isPressed 
                      ? [
                          BoxShadow(
                            color: widget.color.withOpacity(0.7),
                            spreadRadius: 2,
                            blurRadius: 4,
                          )
                        ] 
                      : null,
                  ),
                ),
                // Pad label
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ImprovedPianoKeyboard extends StatefulWidget {
  final Function(int noteNumber, int velocity) onNoteOn;
  final Function(int noteNumber) onNoteOff;
  final Map<int, bool> activeNotes;

  const ImprovedPianoKeyboard({
    Key? key,
    required this.onNoteOn,
    required this.onNoteOff,
    required this.activeNotes,
  }) : super(key: key);

  @override
  State<ImprovedPianoKeyboard> createState() => _ImprovedPianoKeyboardState();
}

class _ImprovedPianoKeyboardState extends State<ImprovedPianoKeyboard> {
  final int _startNote = 60; // Middle C
  final int _numWhiteKeys = 14; // Two octaves of white keys

  // Get all notes (white and black) in the range
  List<int> get _allNotes {
    final List<int> notes = [];
    for (int i = 0; i < _numWhiteKeys + 5; i++) { // Add some extra for black keys
      notes.add(_startNote + i);
    }
    return notes;
  }

  // Get only white keys
  List<int> get _whiteKeys {
    return _allNotes.where((note) => !_isBlackKey(note)).toList();
  }

  // Get only black keys
  List<int> get _blackKeys {
    return _allNotes.where((note) => _isBlackKey(note)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final whiteKeyWidth = constraints.maxWidth / _numWhiteKeys;
        final blackKeyWidth = whiteKeyWidth * 0.6;
        final whiteKeyHeight = constraints.maxHeight;
        final blackKeyHeight = whiteKeyHeight * 0.6;
        
        return Stack(
          children: [
            // White keys
            Row(
              children: _whiteKeys.map((noteNumber) {
                final isActive = widget.activeNotes[noteNumber] == true;
                return GestureDetector(
                  onTapDown: (_) => widget.onNoteOn(noteNumber, 100),
                  onTapUp: (_) => widget.onNoteOff(noteNumber),
                  onTapCancel: () => widget.onNoteOff(noteNumber),
                  child: Container(
                    width: whiteKeyWidth,
                    height: whiteKeyHeight,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.grey[300] : Colors.white,
                      border: Border.all(color: Colors.black, width: 1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(5),
                        bottomRight: Radius.circular(5),
                      ),
                      boxShadow: isActive ? [] : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _getNoteLabel(noteNumber),
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            // Black keys
            Stack(
              children: _blackKeys.map((noteNumber) {
                final isActive = widget.activeNotes[noteNumber] == true;
                
                // Calculate position for black key
                final index = noteNumber - _startNote;
                final octave = index ~/ 12;
                final noteInOctave = index % 12;
                
                // Calculate how many white keys come before this black key
                int whiteKeysBefore = 0;
                for (int i = 0; i < index; i++) {
                  if (!_isBlackKey(_startNote + i)) {
                    whiteKeysBefore++;
                  }
                }
                
                // Adjust position based on the note
                double position = whiteKeysBefore * whiteKeyWidth - blackKeyWidth / 2;
                
                return Positioned(
                  left: position,
                  child: GestureDetector(
                    onTapDown: (_) => widget.onNoteOn(noteNumber, 100),
                    onTapUp: (_) => widget.onNoteOff(noteNumber),
                    onTapCancel: () => widget.onNoteOff(noteNumber),
                    child: Container(
                      width: blackKeyWidth,
                      height: blackKeyHeight,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.grey[700] : Colors.black,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                        boxShadow: isActive ? [] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 2,
                          ),
                        ],
                        gradient: isActive ? null : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
  
  bool _isBlackKey(int noteNumber) {
    final note = noteNumber % 12;
    return [1, 3, 6, 8, 10].contains(note);
  }
  
  String _getNoteLabel(int noteNumber) {
    final note = noteNumber % 12;
    final octave = (noteNumber / 12).floor() - 1;
    
    switch (note) {
      case 0: return 'C$octave';
      case 2: return 'D$octave';
      case 4: return 'E$octave';
      case 5: return 'F$octave';
      case 7: return 'G$octave';
      case 9: return 'A$octave';
      case 11: return 'B$octave';
      default: return '';
    }
  }
}
