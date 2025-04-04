import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multitracker/flutter_multitracker.dart';
import 'package:flutter_multitracker/flutter_multitracker_method_channel.dart';
import 'package:flutter_multitracker/flutter_multitracker_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:developer' as developer;

import 'sequencer_demo.dart';
import 'audio_helper.dart';

/// Helper function for consistent logging
void _log(String message) {
  developer.log(message, name: 'MultiTrackerExample');
  debugPrint('MultiTrackerExample: $message');
}

void main() {
  _log('Starting Flutter Multitracker Example app');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  bool _audioEngineInitialized = false;
  bool _isPlayingTestTone = false;
  bool _useNativeAudio = false; // Default to fallback audio
  
  // Create an instance of FlutterMultitracker
  final _flutterMultitrackerPlugin = FlutterMultitracker();
  
  // Fallback audio helper
  final AudioHelper _audioHelper = AudioHelper();
  
  // Get the method channel implementation for configuration
  late final MethodChannelFlutterMultitracker _methodChannel;
  
  // Piano keyboard state
  final Map<int, bool> _activeNotes = {};
  
  @override
  void initState() {
    super.initState();
    
    // Get the method channel implementation
    _methodChannel = FlutterMultitrackerPlatform.instance as MethodChannelFlutterMultitracker;
    
    initPlatformState();
    _initializeAudioEngine();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    bool audioEngineInitialized;
    
    try {
      platformVersion = await _flutterMultitrackerPlugin.getPlatformVersion() ?? 'Unknown platform version';
      
      if (_useNativeAudio) {
        // For native audio, disable fallback mode
        _methodChannel.setUseFallback(false);
        audioEngineInitialized = await _flutterMultitrackerPlugin.initialize(sampleRate: 44100);
      } else {
        // For fallback audio, initialize the audio helper directly
        audioEngineInitialized = await _audioHelper.initialize();
        
        // Enable fallback mode in the method channel
        _methodChannel.setUseFallback(true);
      }
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
      audioEngineInitialized = false;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _audioEngineInitialized = audioEngineInitialized;
    });
  }
  
  Future<void> _playTestTone() async {
    bool success;
    
    if (_useNativeAudio) {
      success = await _flutterMultitrackerPlugin.playTestTone();
    } else {
      // When using fallback mode, the method channel will "succeed" but we need to play the actual tone
      await _flutterMultitrackerPlugin.playTestTone(); // This won't actually play anything in fallback mode
      success = await _audioHelper.playTestTone();
    }
    
    setState(() {
      _isPlayingTestTone = success;
    });
  }
  
  Future<void> _stopTestTone() async {
    if (_useNativeAudio) {
      await _flutterMultitrackerPlugin.stopTestTone();
    } else {
      // When using fallback mode, the method channel will "succeed" but we need to stop the actual tone
      await _flutterMultitrackerPlugin.stopTestTone(); // This won't actually stop anything in fallback mode
      await _audioHelper.stopTestTone();
    }
    
    setState(() {
      _isPlayingTestTone = false;
    });
  }
  
  Future<void> _toggleAudioMode() async {
    // Stop any playing notes first
    await _stopAllNotes();
    
    setState(() {
      _useNativeAudio = !_useNativeAudio;
      _audioEngineInitialized = false;
    });
    
    // Re-initialize with the new mode
    await initPlatformState();
  }
  
  Future<void> _playNote(int noteNumber) async {
    if (!_audioEngineInitialized) return;
    
    bool success;
    
    if (_useNativeAudio) {
      // Default instrument ID is 0
      success = await _flutterMultitrackerPlugin.playNote(0, noteNumber, 100);
    } else {
      // When using fallback mode, the method channel will "succeed" but we need to play the actual note
      await _flutterMultitrackerPlugin.playNote(0, noteNumber, 100); // This won't actually play anything in fallback mode
      success = await _audioHelper.playNote(0, noteNumber, 100);
    }
    
    if (success) {
      setState(() {
        _activeNotes[noteNumber] = true;
      });
    }
  }
  
  Future<void> _stopNote(int noteNumber) async {
    if (!_audioEngineInitialized) return;
    
    if (_useNativeAudio) {
      await _flutterMultitrackerPlugin.stopNote(0, noteNumber);
    } else {
      // When using fallback mode, the method channel will "succeed" but we need to stop the actual note
      await _flutterMultitrackerPlugin.stopNote(0, noteNumber); // This won't actually stop anything in fallback mode
      await _audioHelper.stopNote(0, noteNumber);
    }
    
    setState(() {
      _activeNotes.remove(noteNumber);
    });
  }
  
  Future<void> _stopAllNotes() async {
    if (!_audioEngineInitialized) return;
    
    final noteNumbers = [..._activeNotes.keys];
    for (final noteNumber in noteNumbers) {
      await _stopNote(noteNumber);
    }
    
    if (_isPlayingTestTone) {
      await _stopTestTone();
    }
  }
  
  Future<void> _initializeAudioEngine() async {
    debugPrint('Initializing audio engine...');
    bool initialized = false;
    
    try {
      // Try to initialize native audio engine first
      initialized = await _flutterMultitrackerPlugin.initialize(sampleRate: 44100) ?? false;
      debugPrint('Native audio engine initialized result: $initialized');
      
      if (!initialized) {
        // Fall back to AudioHelper (web audio fallback)
        debugPrint('Native audio initialization failed, falling back to AudioHelper');
        initialized = await _audioHelper.initialize();
        debugPrint('AudioHelper initialized result: $initialized');
      }
    } catch (e) {
      debugPrint('Error initializing audio engine: $e');
      // Fall back to AudioHelper as a last resort
      try {
        debugPrint('Trying AudioHelper as fallback after exception');
        initialized = await _audioHelper.initialize();
        debugPrint('AudioHelper fallback initialized result: $initialized');
      } catch (e) {
        debugPrint('Critical error: AudioHelper fallback also failed: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _audioEngineInitialized = initialized;
      });
    }
    
    debugPrint('Audio engine initialized with result: $initialized');
    
    // Check if assets are available
    _checkAssets();
  }
  
  Future<void> _checkAssets() async {
    try {
      debugPrint('Checking assets availability...');
      
      final assetPaths = [
        'assets/wav/D3.wav',     // With assets/ prefix
        'wav/D3.wav',            // Without assets/ prefix
        'assets/sounds/sine_A4.wav', // With assets/ prefix
        'sounds/sine_A4.wav'     // Without assets/ prefix
      ];
      
      for (final path in assetPaths) {
        try {
          final asset = await DefaultAssetBundle.of(context).load(path);
          debugPrint('Successfully loaded asset: $path (${asset.lengthInBytes} bytes)');
        } catch (e) {
          debugPrint('Failed to load asset: $path - Error: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking assets: $e');
    }
  }
  
  @override
  void dispose() {
    // Clean up resources
    _stopAllNotes();
    _flutterMultitrackerPlugin.dispose();
    _audioHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
              Text(
                'Audio Engine Status: ${_audioEngineInitialized ? 'Initialized' : 'Not Initialized'}',
                style: TextStyle(
                  color: _audioEngineInitialized ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Using: ${_useNativeAudio ? 'Native Audio' : 'Flutter Audio'}'),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _toggleAudioMode,
                    child: const Text('Switch Mode'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _audioEngineInitialized
                    ? (_isPlayingTestTone ? _stopTestTone : _playTestTone)
                    : null,
                child: Text(_isPlayingTestTone ? 'Stop Test Tone' : 'Play Test Tone'),
              ),
              const SizedBox(height: 30),
              const Text('Piano Keyboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildPianoKeyboard(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPianoKeyboard() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _buildPianoKeys(),
      ),
    );
  }
  
  List<Widget> _buildPianoKeys() {
    final keys = <Widget>[];
    
    // Build one octave C4 (60) to C5 (72)
    for (int noteNumber = 60; noteNumber <= 72; noteNumber++) {
      final isBlack = [1, 3, 6, 8, 10].contains(noteNumber % 12);
      final isActive = _activeNotes[noteNumber] == true;
      
      // Get note name (C, C#, D, etc.)
      final noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
      final noteName = noteNames[noteNumber % 12];
      final octave = (noteNumber / 12).floor() - 1;
      final fullNoteName = '$noteName$octave';
      
      keys.add(
        GestureDetector(
          onTapDown: (_) {
            // If audio engine is initialized, play the note
            if (_audioEngineInitialized) {
              _playNote(noteNumber);
            }
            
            // Always show visual feedback
            setState(() {
              _activeNotes[noteNumber] = true;
            });
            
            // Log press for debugging
            _log('Key pressed: $fullNoteName (MIDI: $noteNumber)');
          },
          onTapUp: (_) {
            // If audio engine is initialized, stop the note
            if (_audioEngineInitialized) {
              _stopNote(noteNumber);
            }
            
            // Always show visual feedback
            setState(() {
              _activeNotes.remove(noteNumber);
            });
            
            // Log release for debugging
            _log('Key released: $fullNoteName (MIDI: $noteNumber)');
          },
          onTapCancel: () {
            // If audio engine is initialized, stop the note
            if (_audioEngineInitialized) {
              _stopNote(noteNumber);
            }
            
            // Always show visual feedback
            setState(() {
              _activeNotes.remove(noteNumber);
            });
            
            // Log cancel for debugging
            _log('Key press cancelled: $fullNoteName (MIDI: $noteNumber)');
          },
          child: Container(
            width: isBlack ? 30 : 40,
            height: isBlack ? 100 : 150,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.blue
                  : (isBlack ? Colors.black : Colors.white),
              border: Border.all(color: Colors.black),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(5),
              ),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              fullNoteName,
              style: TextStyle(
                color: isBlack && !isActive ? Colors.white : Colors.black,
                fontSize: 10,
              ),
            ),
          ),
        ),
      );
    }
    
    return keys;
  }
}
