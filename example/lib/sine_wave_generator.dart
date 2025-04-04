import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class to generate sine wave audio files for testing
class SineWaveGenerator {
  /// Generate sine wave WAV files for common notes
  static Future<void> generateTestTones() async {
    if (kIsWeb) return; // Not supported on web
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final soundsDir = Directory('${directory.path}/sounds');
      
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      // Generate common notes
      final noteNames = {
        60: 'C4', // Middle C
        64: 'E4',
        67: 'G4',
        69: 'A4', // A440
        72: 'C5',
      };
      
      for (final entry in noteNames.entries) {
        final noteNumber = entry.key;
        final noteName = entry.value;
        
        final frequency = _midiNoteToFrequency(noteNumber);
        final filePath = '${soundsDir.path}/sine_$noteName.wav';
        
        await _generateWavFile(filePath, frequency);
        debugPrint('Generated sine wave for $noteName ($frequency Hz) at $filePath');
      }
      
      debugPrint('Generated all test tones in ${soundsDir.path}');
    } catch (e) {
      debugPrint('Error generating test tones: $e');
    }
  }
  
  /// Generate a WAV file with a sine wave at the specified frequency
  static Future<void> _generateWavFile(String filePath, double frequency) async {
    // WAV file parameters
    final sampleRate = 44100;
    final duration = 1.0; // 1 second
    final numSamples = (sampleRate * duration).toInt();
    final amplitude = 0.8; // 80% amplitude
    
    // Create WAV header
    final header = ByteData(44);
    
    // RIFF chunk descriptor
    header.setUint8(0, 'R'.codeUnitAt(0));
    header.setUint8(1, 'I'.codeUnitAt(0));
    header.setUint8(2, 'F'.codeUnitAt(0));
    header.setUint8(3, 'F'.codeUnitAt(0));
    
    // Chunk size: 4 + (8 + SubChunk1Size) + (8 + SubChunk2Size)
    header.setUint32(4, 36 + numSamples * 2, Endian.little);
    
    // Format
    header.setUint8(8, 'W'.codeUnitAt(0));
    header.setUint8(9, 'A'.codeUnitAt(0));
    header.setUint8(10, 'V'.codeUnitAt(0));
    header.setUint8(11, 'E'.codeUnitAt(0));
    
    // Subchunk1 ID: "fmt "
    header.setUint8(12, 'f'.codeUnitAt(0));
    header.setUint8(13, 'm'.codeUnitAt(0));
    header.setUint8(14, 't'.codeUnitAt(0));
    header.setUint8(15, ' '.codeUnitAt(0));
    
    // Subchunk1 size: 16 for PCM
    header.setUint32(16, 16, Endian.little);
    
    // Audio format: 1 for PCM
    header.setUint16(20, 1, Endian.little);
    
    // Number of channels: 1 for mono
    header.setUint16(22, 1, Endian.little);
    
    // Sample rate
    header.setUint32(24, sampleRate, Endian.little);
    
    // Byte rate: SampleRate * NumChannels * BitsPerSample/8
    header.setUint32(28, sampleRate * 1 * 16 ~/ 8, Endian.little);
    
    // Block align: NumChannels * BitsPerSample/8
    header.setUint16(32, 1 * 16 ~/ 8, Endian.little);
    
    // Bits per sample
    header.setUint16(34, 16, Endian.little);
    
    // Subchunk2 ID: "data"
    header.setUint8(36, 'd'.codeUnitAt(0));
    header.setUint8(37, 'a'.codeUnitAt(0));
    header.setUint8(38, 't'.codeUnitAt(0));
    header.setUint8(39, 'a'.codeUnitAt(0));
    
    // Subchunk2 size: NumSamples * NumChannels * BitsPerSample/8
    header.setUint32(40, numSamples * 1 * 16 ~/ 8, Endian.little);
    
    // Create audio data
    final dataSize = numSamples * 2; // 16-bit mono
    final audioData = ByteData(dataSize);
    
    for (int i = 0; i < numSamples; i++) {
      final time = i / sampleRate;
      final angle = 2 * math.pi * frequency * time;
      
      // Apply a small fade-in and fade-out to avoid clicks
      var amp = amplitude;
      if (i < 1000) { // ~23ms fade-in
        amp *= i / 1000;
      } else if (i > numSamples - 1000) { // ~23ms fade-out
        amp *= (numSamples - i) / 1000;
      }
      
      // Generate sine wave sample (-32768 to 32767)
      final sample = (amp * 32767 * math.sin(angle)).toInt();
      audioData.setInt16(i * 2, sample, Endian.little);
    }
    
    // Write WAV file
    final file = File(filePath);
    final sink = file.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(audioData.buffer.asUint8List());
    await sink.close();
  }
  
  /// Convert MIDI note number to frequency
  static double _midiNoteToFrequency(int noteNumber) {
    // A4 (MIDI note 69) is 440Hz
    return 440.0 * math.pow(2, (noteNumber - 69) / 12);
  }
} 