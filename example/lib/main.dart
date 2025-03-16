import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multitracker/flutter_multitracker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

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
  double _masterVolume = 1.0;
  int _instrumentId = -1;
  
  // Piano keyboard state
  final Map<int, bool> _activeNotes = {};
  
  // Create an instance of the plugin
  final FlutterMultitracker _multitracker = FlutterMultitracker();

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
      platformVersion = await FlutterMultitracker.platformVersion ?? 'Unknown platform version';
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
    
    // Initialize the audio engine
    _initAudioEngine();
  }
  
  Future<void> _initAudioEngine() async {
    setState(() {
      _status = 'Initializing...';
    });
    
    try {
      // Initialize the audio engine
      final bool initialized = await _multitracker.initAudioEngine();
      
      if (initialized) {
        // Start the audio engine
        final bool started = await _multitracker.startAudioEngine();
        
        if (started) {
          // Create a sine wave instrument
          final int instrumentId = await _multitracker.createSineWaveInstrument('Piano');
          
          setState(() {
            _isInitialized = true;
            _instrumentId = instrumentId;
            _status = 'Ready to play';
          });
        } else {
          setState(() {
            _status = 'Failed to start audio engine';
          });
        }
      } else {
        setState(() {
          _status = 'Failed to initialize audio engine';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }
  
  Future<void> _cleanup() async {
    if (_isInitialized) {
      // Stop all active notes
      for (final noteNumber in _activeNotes.keys.toList()) {
        if (_activeNotes[noteNumber] == true) {
          await _multitracker.sendNoteOff(_instrumentId, noteNumber);
        }
      }
      
      // Stop the audio engine
      await _multitracker.stopAudioEngine();
      
      // Clean up resources
      await _multitracker.cleanupAudioEngine();
    }
  }
  
  Future<void> _playNote(int noteNumber) async {
    if (_isInitialized && _instrumentId >= 0) {
      await _multitracker.sendNoteOn(_instrumentId, noteNumber, 100);
      
      setState(() {
        _activeNotes[noteNumber] = true;
      });
    }
  }
  
  Future<void> _stopNote(int noteNumber) async {
    if (_isInitialized && _instrumentId >= 0) {
      await _multitracker.sendNoteOff(_instrumentId, noteNumber);
      
      setState(() {
        _activeNotes[noteNumber] = false;
      });
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
          title: const Text('Flutter Multitracker Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Running on: $_platformVersion'),
              const SizedBox(height: 20),
              Text('Status: $_status'),
              const SizedBox(height: 20),
              if (_isInitialized) ...[
                Text('Master Volume: ${(_masterVolume * 100).toStringAsFixed(0)}%'),
                Slider(
                  value: _masterVolume,
                  onChanged: _setMasterVolume,
                  min: 0.0,
                  max: 1.0,
                ),
                const SizedBox(height: 20),
                const Text('Piano Keyboard'),
                const SizedBox(height: 10),
                _buildPianoKeyboard(),
              ] else ...[
                ElevatedButton(
                  onPressed: _initAudioEngine,
                  child: const Text('Initialize Audio Engine'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPianoKeyboard() {
    // Build a simple piano keyboard with one octave (C4 to C5)
    // MIDI note numbers: C4 = 60, C5 = 72
    final List<int> whiteKeys = [60, 62, 64, 65, 67, 69, 71, 72];
    final List<int> blackKeys = [61, 63, 66, 68, 70];
    
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // White keys
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: whiteKeys.map((noteNumber) {
              final bool isActive = _activeNotes[noteNumber] == true;
              return GestureDetector(
                onTapDown: (_) => _playNote(noteNumber),
                onTapUp: (_) => _stopNote(noteNumber),
                onTapCancel: () => _stopNote(noteNumber),
                child: Container(
                  width: 40,
                  height: 200,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.grey[300] : Colors.white,
                    border: Border.all(color: Colors.black),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(5),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _getNoteLabel(noteNumber),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Black keys
          Positioned(
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 25), // Offset for C#
                _buildBlackKey(blackKeys[0]), // C#
                const SizedBox(width: 10), // Space
                _buildBlackKey(blackKeys[1]), // D#
                const SizedBox(width: 40), // Skip E
                _buildBlackKey(blackKeys[2]), // F#
                const SizedBox(width: 10), // Space
                _buildBlackKey(blackKeys[3]), // G#
                const SizedBox(width: 10), // Space
                _buildBlackKey(blackKeys[4]), // A#
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBlackKey(int noteNumber) {
    final bool isActive = _activeNotes[noteNumber] == true;
    return GestureDetector(
      onTapDown: (_) => _playNote(noteNumber),
      onTapUp: (_) => _stopNote(noteNumber),
      onTapCancel: () => _stopNote(noteNumber),
      child: Container(
        width: 30,
        height: 120,
        decoration: BoxDecoration(
          color: isActive ? Colors.grey[700] : Colors.black,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
        ),
      ),
    );
  }
  
  String _getNoteLabel(int noteNumber) {
    final List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final int octave = (noteNumber / 12).floor() - 1;
    final int noteIndex = noteNumber % 12;
    return '${noteNames[noteIndex]}$octave';
  }
}
