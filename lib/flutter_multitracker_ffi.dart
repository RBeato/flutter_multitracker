import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:ffi/ffi.dart';

/// Callback function type for native to Dart callbacks
typedef NativeCallbackType = void Function(int type, int data1, int data2, double data3);

/// FFI implementation for flutter_multitracker
class MultiTrackerFFI {
  /// Singleton instance
  static final MultiTrackerFFI _instance = MultiTrackerFFI._internal();
  
  /// Dynamic library instance
  DynamicLibrary? _nativeLib;
  
  /// Initialization state tracking
  bool _isInitialized = false;
  String? _initializationError;
  final Completer<bool> _initializationCompleter = Completer<bool>();
  
  /// Callback port and stream
  final ReceivePort _callbackPort = ReceivePort();
  late final StreamSubscription _callbackSubscription;
  final _callbacks = <int, NativeCallbackType>{};
  int _nextCallbackId = 1;
  
  /// Default timeout for native operations
  static const Duration defaultTimeout = Duration(seconds: 5);
  
  /// Factory constructor for singleton access
  factory MultiTrackerFFI() {
    developer.log('Creating MultiTrackerFFI instance', name: 'MultiTrackerFFI');
    return _instance;
  }
  
  /// Private constructor to prevent direct instantiation
  MultiTrackerFFI._internal() {
    developer.log('Initializing MultiTrackerFFI singleton', name: 'MultiTrackerFFI');
    // Set up the callback handling
    _setupCallbacks();
  }
  
  /// Sets up the callback mechanism for native to Dart communication
  void _setupCallbacks() {
    _log('Setting up callback mechanism');
    _callbackSubscription = _callbackPort.listen((dynamic message) {
      if (message is List && message.length >= 4) {
        final callbackId = message[0] as int;
        final data1 = message[1] as int;
        final data2 = message[2] as int;
        final data3 = message[3] as double;
        
        _log('Received callback: id=$callbackId, data1=$data1, data2=$data2, data3=$data3');
        
        if (_callbacks.containsKey(callbackId)) {
          try {
            _callbacks[callbackId]!(callbackId, data1, data2, data3);
          } catch (e) {
            _log('Error in callback $callbackId: $e');
          }
        } else {
          _log('Warning: Callback ID $callbackId not found');
        }
      } else {
        _log('Warning: Received invalid callback message format: $message');
      }
    });
  }
  
  /// Logger function
  void _log(String message) {
    developer.log(message, name: 'MultiTrackerFFI');
  }
  
  /// Register a callback function to receive events from native code
  int registerCallback(NativeCallbackType callback) {
    final id = _nextCallbackId++;
    _callbacks[id] = callback;
    _log('Registered callback with ID: $id');
    return id;
  }
  
  /// Unregister a callback
  void unregisterCallback(int callbackId) {
    _callbacks.remove(callbackId);
    _log('Unregistered callback with ID: $callbackId');
  }
  
  /// Initialize the FFI library with thread safety, error handling, and timeout
  /// Returns a future that completes when initialization is done or fails after timeout
  Future<bool> initialize({Duration timeout = defaultTimeout}) async {
    _log('Initialize called, isInitialized=$_isInitialized, completer.isCompleted=${_initializationCompleter.isCompleted}');
    
    // If already initialized or initializing, return the existing future
    if (_isInitialized) {
      _log('Already initialized, returning true');
      return true;
    }
    
    if (_initializationCompleter.isCompleted) {
      if (_initializationError != null) {
        _log('Initialization previously failed: $_initializationError');
        throw Exception('Failed to initialize FFI: $_initializationError');
      }
      _log('Initialization already in progress, returning existing future');
      return await _initializationCompleter.future;
    }
    
    // Create a completer that can be completed by timeout or success
    final timeoutCompleter = Completer<bool>();
    
    // Set up timeout handler
    final timer = Timer(timeout, () {
      if (!timeoutCompleter.isCompleted) {
        _log('Initialization timed out after ${timeout.inMilliseconds}ms');
        _initializationError = 'Initialization timed out after ${timeout.inMilliseconds}ms';
        timeoutCompleter.complete(false);
        if (!_initializationCompleter.isCompleted) {
          _initializationCompleter.complete(false);
        }
      }
    });
    
    // Perform initialization in a try-catch block
    try {
      _log('Starting initialization process');
      
      // Load the appropriate dynamic library for the platform
      if (Platform.isAndroid) {
        _log('Loading Android library: libflutter_multitracker.so');
        _nativeLib = DynamicLibrary.open('libflutter_multitracker.so');
        _log('Android library loaded successfully');
      } else if (Platform.isIOS) {
        _log('Loading iOS library via process');
        _nativeLib = DynamicLibrary.process();
        _log('iOS library loaded successfully');
      } else {
        final error = 'Unsupported platform: ${Platform.operatingSystem}';
        _log(error);
        throw UnsupportedError(error);
      }
      
      // Initialize the callback mechanism if the native code supports it
      try {
        _log('Registering Dart callback port with native code');
        final registerPort = _nativeLib!
          .lookupFunction<Pointer<Void> Function(Int64), Pointer<Void> Function(int)>(
            'register_dart_callback_port');
            
        // Send the native side the port for callbacks
        final portPtr = registerPort(_callbackPort.sendPort.nativePort);
        _log('Callback port registered successfully, returned pointer: $portPtr');
        
        // Verify registration was successful
        if (portPtr == nullptr) {
          throw Exception('Failed to register callback port - null pointer returned');
        }
      } catch (e) {
        // Callback registration is optional - log but continue
        _log('Callback registration not available or failed: $e');
      }
      
      // Verify the native library is properly initialized by calling a test function
      try {
        final testFunc = _nativeLib!.lookupFunction<Int8 Function(), int Function()>('test_init');
        final result = testFunc();
        if (result != 1) {
          throw Exception('Native library initialization test failed with code: $result');
        }
        _log('Native library initialization verified successfully');
      } catch (e) {
        _log('Native library test function failed: $e');
        // Continue anyway, as the test function might not exist in all versions
      }
      
      _isInitialized = true;
      _initializationCompleter.complete(true);
      timeoutCompleter.complete(true);
      _log('MultiTrackerFFI initialized successfully');
      return true;
    } catch (e) {
      _initializationError = e.toString();
      _log('Error initializing MultiTrackerFFI: $e');
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete(false);
      }
      if (!timeoutCompleter.isCompleted) {
        timeoutCompleter.complete(false);
      }
      return false;
    } finally {
      // Cancel the timeout timer
      timer.cancel();
    }
  }
  
  /// Ensure the library is initialized before accessing methods
  /// Throws an exception if initialization failed
  void _ensureInitialized() {
    if (!_isInitialized) {
      _log('Error: FFI not initialized');
      throw Exception('FFI not initialized. Call initialize() first.');
    }
    if (_nativeLib == null) {
      _log('Error: Native library not loaded');
      throw Exception('Native library not loaded.');
    }
  }
  
  /// Look up a function in the native library with proper error handling and timeout
  dynamic _lookupFunctionInternal(String symbolName, {bool isRequired = true}) {
    _ensureInitialized();
    
    try {
      _log('Looking up function: $symbolName');
      final result = _nativeLib!.lookup(symbolName);
      _log('Function $symbolName found: $result');
      return result;
    } catch (e) {
      if (isRequired) {
        _log('Error looking up required function $symbolName: $e');
        rethrow;
      }
      _log('Warning: Function $symbolName not found in native library');
      throw Exception('Function $symbolName not found in native library');
    }
  }
  
  /// Execute a native function with timeout
  /// Returns a Future that completes with the result or times out
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() operation, 
    String operationName, 
    {Duration timeout = defaultTimeout}
  ) async {
    _log('Executing $operationName with timeout ${timeout.inMilliseconds}ms');
    
    try {
      return await operation().timeout(timeout, onTimeout: () {
        final message = '$operationName timed out after ${timeout.inMilliseconds}ms';
        _log(message);
        throw TimeoutException(message);
      });
    } catch (e) {
      _log('Error in $operationName: $e');
      rethrow;
    }
  }
  
  /// Clean up resources with comprehensive error handling
  Future<bool> dispose() async {
    _log('Disposing MultiTrackerFFI resources');
    try {
      if (_isInitialized) {
        // Execute cleanup with timeout protection
        return await _executeWithTimeout(() async {
          _callbackSubscription.cancel();
          _callbackPort.close();
          _callbacks.clear();
          
          // Call native dispose if initialized
          try {
            _log('Calling native dispose function');
            final disposeFunc = _nativeLib?.lookupFunction<Int8 Function(), int Function()>('dispose');
            if (disposeFunc != null) {
              final result = disposeFunc();
              _log('Native dispose returned: $result');
              if (result != 1) {
                _log('Warning: Native dispose returned unexpected result: $result');
              }
            }
          } catch (e) {
            _log('Error during native dispose: $e');
            // Continue cleanup even if native dispose fails
          }
          
          _isInitialized = false;
          _log('MultiTrackerFFI disposed successfully');
          return true;
        }, 'dispose');
      } else {
        _log('Dispose called but FFI was not initialized');
        return true;
      }
    } catch (e) {
      _log('Error disposing MultiTrackerFFI: $e');
      return false;
    }
  }
  
  // === FFI Function Wrappers with Error Handling and Timeouts ===
  
  /// Initialize the audio engine with timeout
  Future<int> initAudioEngine(int sampleRate, {Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Initializing audio engine with sample rate: $sampleRate');
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32), int Function(int)>('init_audio_engine');
      final result = func(sampleRate);
      _log('Audio engine initialization returned: $result');
      
      if (result != 1) {
        throw Exception('Failed to initialize audio engine, code: $result');
      }
      
      return result;
    }, 'initAudioEngine', timeout: timeout);
  }
    
  /// Start the audio engine with timeout
  Future<int> startAudioEngine({Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Starting audio engine');
      final func = _nativeLib!.lookupFunction<Int8 Function(), int Function()>('start_audio_engine');
      final result = func();
      _log('Audio engine start returned: $result');
      
      if (result != 1) {
        throw Exception('Failed to start audio engine, code: $result');
      }
      
      return result;
    }, 'startAudioEngine', timeout: timeout);
  }
    
  /// Stop the audio engine with timeout
  Future<int> stopAudioEngine({Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Stopping audio engine');
      final func = _nativeLib!.lookupFunction<Int8 Function(), int Function()>('stop_audio_engine');
      final result = func();
      _log('Audio engine stop returned: $result');
      
      if (result != 1) {
        throw Exception('Failed to stop audio engine, code: $result');
      }
      
      return result;
    }, 'stopAudioEngine', timeout: timeout);
  }
    
  /// Load instrument from SFZ file with timeout
  Future<int> loadInstrumentFromSFZ(String sfzPath, {Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Loading SFZ instrument from path: $sfzPath');
      // Use the FFI package's utilities to convert strings
      final pathPointer = sfzPath.toNativeUtf8(allocator: malloc);
      try {
        final func = _nativeLib!.lookupFunction<Int32 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>('load_instrument_sfz');
        final result = func(pathPointer);
        _log('Load SFZ instrument returned ID: $result');
        
        if (result < 0) {
          throw Exception('Failed to load SFZ instrument, code: $result');
        }
        
        return result;
      } finally {
        _log('Freeing SFZ path pointer');
        malloc.free(pathPointer);
      }
    }, 'loadInstrumentFromSFZ', timeout: timeout);
  }
    
  /// Load instrument from SF2 file with timeout
  Future<int> loadInstrumentFromSF2(String sf2Path, int preset, int bank, {Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Loading SF2 instrument from path: $sf2Path, preset: $preset, bank: $bank');
      // Use the FFI package's utilities to convert strings
      final pathPointer = sf2Path.toNativeUtf8(allocator: malloc);
      try {
        final func = _nativeLib!.lookupFunction<Int32 Function(Pointer<Utf8>, Int32, Int32), int Function(Pointer<Utf8>, int, int)>('load_instrument_sf2');
        final result = func(pathPointer, preset, bank);
        _log('Load SF2 instrument returned ID: $result');
        
        if (result < 0) {
          throw Exception('Failed to load SF2 instrument, code: $result');
        }
        
        return result;
      } finally {
        _log('Freeing SF2 path pointer');
        malloc.free(pathPointer);
      }
    }, 'loadInstrumentFromSF2', timeout: timeout);
  }
                            
  /// Create a sequence with timeout
  Future<int> createSequence(double bpm, int timeSignatureNumerator, int timeSignatureDenominator, {Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Creating sequence with BPM: $bpm, time signature: $timeSignatureNumerator/$timeSignatureDenominator');
      final func = _nativeLib!.lookupFunction<Int32 Function(Float, Int32, Int32), int Function(double, int, int)>('create_sequence');
      final result = func(bpm, timeSignatureNumerator, timeSignatureDenominator);
      _log('Create sequence returned ID: $result');
      
      if (result < 0) {
        throw Exception('Failed to create sequence, code: $result');
      }
      
      return result;
    }, 'createSequence', timeout: timeout);
  }
                            
  /// Add a track to a sequence with timeout
  Future<int> addTrack(int sequenceId, int instrumentId, {Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Adding track to sequence ID: $sequenceId with instrument ID: $instrumentId');
      final func = _nativeLib!.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>('add_track');
      final result = func(sequenceId, instrumentId);
      _log('Add track returned ID: $result');
      
      if (result < 0) {
        throw Exception('Failed to add track, code: $result');
      }
      
      return result;
    }, 'addTrack', timeout: timeout);
  }
                            
  /// Add a note to a track with timeout
  Future<bool> addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startBeat, double durationBeats, {Duration timeout = defaultTimeout}) async {
    return await _executeWithTimeout(() async {
      _ensureInitialized();
      
      _log('Adding note to track ID: $trackId in sequence ID: $sequenceId, note: $noteNumber, velocity: $velocity, start: $startBeat, duration: $durationBeats');
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32, Int32, Int32, Int32, Float, Float), int Function(int, int, int, int, double, double)>('add_note');
      final result = func(sequenceId, trackId, noteNumber, velocity, startBeat, durationBeats);
      _log('Add note returned: $result');
      
      return result == 1;
    }, 'addNote', timeout: timeout);
  }
                            
  /// Play a sequence
  int playSequence(int sequenceId, int loop) {
    _ensureInitialized();
    
    _log('Playing sequence ID: $sequenceId, loop: $loop');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32, Int8), int Function(int, int)>('play_sequence');
      final result = func(sequenceId, loop);
      _log('Play sequence returned: $result');
      return result;
    } catch (e) {
      _log('Error playing sequence: $e');
      return 0;
    }
  }
                            
  /// Stop a sequence
  int stopSequence(int sequenceId) {
    _ensureInitialized();
    
    _log('Stopping sequence ID: $sequenceId');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32), int Function(int)>('stop_sequence');
      final result = func(sequenceId);
      _log('Stop sequence returned: $result');
      return result;
    } catch (e) {
      _log('Error stopping sequence: $e');
      return 0;
    }
  }
                            
  /// Delete a sequence
  int deleteSequence(int sequenceId) {
    _ensureInitialized();
    
    _log('Deleting sequence ID: $sequenceId');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32), int Function(int)>('delete_sequence');
      final result = func(sequenceId);
      _log('Delete sequence returned: $result');
      return result;
    } catch (e) {
      _log('Error deleting sequence: $e');
      return 0;
    }
  }
                            
  /// Set playback position
  int setPlaybackPosition(int sequenceId, double beat) {
    _ensureInitialized();
    
    _log('Setting playback position of sequence ID: $sequenceId to beat: $beat');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32, Float), int Function(int, double)>('set_playback_position');
      final result = func(sequenceId, beat);
      _log('Set playback position returned: $result');
      return result;
    } catch (e) {
      _log('Error setting playback position: $e');
      return 0;
    }
  }
                            
  /// Get playback position
  double getPlaybackPosition(int sequenceId) {
    _ensureInitialized();
    
    _log('Getting playback position of sequence ID: $sequenceId');
    try {
      final func = _nativeLib!.lookupFunction<Float Function(Int32), double Function(int)>('get_playback_position');
      final result = func(sequenceId);
      _log('Get playback position returned: $result');
      return result;
    } catch (e) {
      _log('Error getting playback position: $e');
      return 0.0;
    }
  }
                            
  /// Set master volume
  int setMasterVolume(double volume) {
    _ensureInitialized();
    
    _log('Setting master volume to: $volume');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Float), int Function(double)>('set_master_volume');
      final result = func(volume);
      _log('Set master volume returned: $result');
      return result;
    } catch (e) {
      _log('Error setting master volume: $e');
      return 0;
    }
  }
                            
  /// Set track volume
  int setTrackVolume(int sequenceId, int trackId, double volume) {
    _ensureInitialized();
    
    _log('Setting volume of track ID: $trackId in sequence ID: $sequenceId to: $volume');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32, Int32, Float), int Function(int, int, double)>('set_track_volume');
      final result = func(sequenceId, trackId, volume);
      _log('Set track volume returned: $result');
      return result;
    } catch (e) {
      _log('Error setting track volume: $e');
      return 0;
    }
  }
  
  /// Send a note on message to play a note
  int sendNoteOn(int instrumentId, int noteNumber, int velocity) {
    _ensureInitialized();
    
    _log('Sending Note On: instrument=$instrumentId, note=$noteNumber, velocity=$velocity');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32, Int32, Int32), int Function(int, int, int)>('play_note');
      final result = func(instrumentId, noteNumber, velocity);
      _log('Note On returned: $result');
      return result;
    } catch (e) {
      _log('Error sending Note On: $e');
      return 0;
    }
  }
  
  /// Send a note off message to stop a note
  int sendNoteOff(int instrumentId, int noteNumber) {
    _ensureInitialized();
    
    _log('Sending Note Off: instrument=$instrumentId, note=$noteNumber');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(Int32, Int32), int Function(int, int)>('stop_note');
      final result = func(instrumentId, noteNumber);
      _log('Note Off returned: $result');
      return result;
    } catch (e) {
      _log('Error sending Note Off: $e');
      return 0;
    }
  }
                            
  /// Play a test tone to verify audio output
  int playTestTone() {
    _ensureInitialized();
    
    _log('Playing test tone');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(), int Function()>('play_test_tone');
      final result = func();
      _log('Play test tone returned: $result');
      return result;
    } catch (e) {
      _log('Error playing test tone: $e');
      return 0;
    }
  }
  
  /// Stop the test tone
  int stopTestTone() {
    _ensureInitialized();
    
    _log('Stopping test tone');
    try {
      final func = _nativeLib!.lookupFunction<Int8 Function(), int Function()>('stop_test_tone');
      final result = func();
      _log('Stop test tone returned: $result');
      return result;
    } catch (e) {
      _log('Error stopping test tone: $e');
      return 0;
    }
  }
                            
  /// Dispose and clean up resources - kept for backward compatibility
  int cleanup() {
    _log('Cleanup called (backward compatibility method)');
    dispose();
    return 1;  // Return success
  }
} 