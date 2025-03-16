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
  
  // Instrument type selection
  String _selectedInstrumentType = 'Sine Wave';
  final List<String> _instrumentTypes = ['Sine Wave', 'Piano Samples', 'Guitar Samples'];
  
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
      // Create a piano instrument using WAV samples
      final instrument = await _multitracker.createInstrument('Piano Samples', 'sample');
      
      if (instrument != null) {
        _sampleInstrumentId = instrument.id;
        
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
            
            debugPrint('Extracted sample file: $filePath');
            
            // Note: We don't have a direct method to load samples in the current API
            // This would need to be implemented in the native code
          } catch (e) {
            debugPrint('Error loading sample $assetPath: $e');
          }
        }
        
        debugPrint('Created sample instrument with ID: $_sampleInstrumentId');
      }
    } catch (e) {
      debugPrint('Error creating sample instruments: $e');
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
      case 'Guitar Samples':
        // Add guitar instrument ID when implemented
        return _instrumentId;
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
  
  Future<void> _setMasterVolume(double volume) async {
    if (_isInitialized) {
      await _multitracker.setMasterVolume(volume);
      
      setState(() {
        _masterVolume = volume;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(_currentPage == 0 ? 'Piano Demo' : 'Sequencer Demo'),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text(
                  'Flutter Multitracker Demo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Piano Demo'),
                selected: _currentPage == 0,
                onTap: () {
                  setState(() {
                    _currentPage = 0;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Sequencer Demo'),
                selected: _currentPage == 1,
                onTap: () {
                  setState(() {
                    _currentPage = 1;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        body: _isInitialized 
          ? _currentPage == 0 ? _buildPianoDemo() : const SequencerDemo()
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
      ),
    );
  }
  
  Widget _buildPianoDemo() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Running on: $_platformVersion'),
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
                  value: _masterVolume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    setState(() {
                      _masterVolume = value;
                    });
                    _multitracker.setMasterVolume(value);
                  },
                ),
              ),
              Text('${(_masterVolume * 100).toInt()}%'),
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
                    });
                    _updateEnvelope();
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
                    });
                    _updateEnvelope();
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
                    });
                    _updateEnvelope();
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
                    });
                    _updateEnvelope();
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
          child: PianoKeyboard(
            onNoteOn: (noteNumber, velocity) {
              final int instrumentId = _getActiveInstrumentId();
              _multitracker.noteOn(instrumentId, noteNumber, velocity);
            },
            onNoteOff: (noteNumber) {
              final int instrumentId = _getActiveInstrumentId();
              _multitracker.noteOff(instrumentId, noteNumber);
            },
          ),
        ),
      ],
    );
  }
  
  void _updateEnvelope() {
    final int instrumentId = _getActiveInstrumentId();
    _multitracker.setInstrumentEnvelope(
      instrumentId,
      _attack,
      _decay,
      _sustain,
      _release,
    );
  }
}

class PianoKeyboard extends StatefulWidget {
  final Function(int noteNumber, int velocity) onNoteOn;
  final Function(int noteNumber) onNoteOff;

  const PianoKeyboard({
    Key? key,
    required this.onNoteOn,
    required this.onNoteOff,
  }) : super(key: key);

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final Set<int> _pressedKeys = {};
  final int _startNote = 60; // Middle C
  final int _numKeys = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final whiteKeyWidth = constraints.maxWidth / (_numKeys * 7/12);
        final blackKeyWidth = whiteKeyWidth * 0.6;
        final whiteKeyHeight = constraints.maxHeight;
        final blackKeyHeight = whiteKeyHeight * 0.6;
        
        return Stack(
          children: [
            // White keys
            Row(
              children: List.generate(_numKeys, (index) {
                final noteNumber = _startNote + index;
                final isWhiteKey = !_isBlackKey(noteNumber);
                
                if (isWhiteKey) {
                  return GestureDetector(
                    onTapDown: (_) => _handleNoteOn(noteNumber),
                    onTapUp: (_) => _handleNoteOff(noteNumber),
                    onTapCancel: () => _handleNoteOff(noteNumber),
                    child: Container(
                      width: whiteKeyWidth,
                      height: whiteKeyHeight,
                      decoration: BoxDecoration(
                        color: _pressedKeys.contains(noteNumber) ? Colors.grey[300] : Colors.white,
                        border: Border.all(color: Colors.black, width: 1),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                      ),
                    ),
                  );
                } else {
                  return SizedBox(width: whiteKeyWidth);
                }
              }),
            ),
            
            // Black keys
            Row(
              children: List.generate(_numKeys, (index) {
                final noteNumber = _startNote + index;
                final isBlackKey = _isBlackKey(noteNumber);
                
                if (isBlackKey) {
                  // Calculate position for black key
                  final prevWhiteKeyCount = _countWhiteKeysBeforeIndex(index);
                  final position = prevWhiteKeyCount * whiteKeyWidth - blackKeyWidth / 2;
                  
                  return Padding(
                    padding: EdgeInsets.only(left: position),
                    child: GestureDetector(
                      onTapDown: (_) => _handleNoteOn(noteNumber),
                      onTapUp: (_) => _handleNoteOff(noteNumber),
                      onTapCancel: () => _handleNoteOff(noteNumber),
                      child: Container(
                        width: blackKeyWidth,
                        height: blackKeyHeight,
                        decoration: BoxDecoration(
                          color: _pressedKeys.contains(noteNumber) ? Colors.grey[700] : Colors.black,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(5),
                            bottomRight: Radius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
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
  
  int _countWhiteKeysBeforeIndex(int index) {
    int count = 0;
    for (int i = 0; i < index; i++) {
      if (!_isBlackKey(_startNote + i)) {
        count++;
      }
    }
    return count;
  }
  
  void _handleNoteOn(int noteNumber) {
    if (!_pressedKeys.contains(noteNumber)) {
      setState(() {
        _pressedKeys.add(noteNumber);
      });
      widget.onNoteOn(noteNumber, 100); // Default velocity
    }
  }
  
  void _handleNoteOff(int noteNumber) {
    if (_pressedKeys.contains(noteNumber)) {
      setState(() {
        _pressedKeys.remove(noteNumber);
      });
      widget.onNoteOff(noteNumber);
    }
  }
}
