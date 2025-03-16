# flutter_multitracker

A Flutter plugin for music sequencing and sampler instrument playback on iOS and Android. This plugin provides a powerful API for creating multi-track music sequences with support for SFZ and SF2 sampler instruments, as well as AudioUnit instruments on iOS.

Take inspiration from this project: https://github.com/mikeperri/flutter_sequencer

## Features

- Load and play SFZ format sampler instruments using the sfizz library
- Load and play SoundFont (SF2) format instruments (coming soon)
- iOS-only: Load and play AudioUnit instruments (coming soon)
- Create multi-track sequences with precise timing
- Add notes with specific MIDI note numbers, velocities, and durations
- Control volume with automation points for dynamic changes
- Play, stop, and loop sequences
- Set playback position for precise control
- Adjust master and per-track volume levels
- Thread-safe native audio engine implementation

## Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  flutter_multitracker: ^0.0.1
```

### iOS Setup

Add the following to your `Info.plist` file:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for audio processing</string>
```

### Android Setup

Add the following permissions to your `AndroidManifest.xml` file:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## Usage

### Initialization

```dart
import 'package:flutter_multitracker/flutter_multitracker.dart';

// Get the singleton instance
final sequencer = FlutterMultitracker();

// Initialize the audio engine
await sequencer.initialize();
```

### Loading Instruments

```dart
// Load an SFZ instrument
final sfzInstrumentId = await sequencer.loadInstrumentFromSFZ('path/to/instrument.sfz');

// Load an SF2 instrument with specific preset and bank
final sf2InstrumentId = await sequencer.loadInstrumentFromSF2(
  'path/to/soundfont.sf2',
  preset: 0,
  bank: 0,
);

// iOS only: Load an AudioUnit instrument
if (Platform.isIOS) {
  final auInstrumentId = await sequencer.loadAudioUnitInstrument(
    'aumu,samp,appl', // Component description
    auPresetPath: 'path/to/preset.aupreset', // Optional
  );
}
```

### Creating Sequences

```dart
// Create a sequence at 120 BPM with 4/4 time signature
final sequenceId = await sequencer.createSequence(
  120.0,
  timeSignatureNumerator: 4,
  timeSignatureDenominator: 4,
);

// Add a track using the loaded instrument
final trackId = await sequencer.addTrack(sequenceId, sfzInstrumentId);

// Add notes to the track
await sequencer.addNote(
  sequenceId,
  trackId,
  60, // C4 note
  100, // Velocity
  0.0, // Start at the beginning
  1.0, // Duration of 1 beat
);

// Add more notes
await sequencer.addNote(sequenceId, trackId, 64, 100, 1.0, 1.0); // E4
await sequencer.addNote(sequenceId, trackId, 67, 100, 2.0, 1.0); // G4
await sequencer.addNote(sequenceId, trackId, 72, 100, 3.0, 1.0); // C5

// Add volume automation
await sequencer.addVolumeAutomation(sequenceId, trackId, 0.0, 0.5); // Start at 50%
await sequencer.addVolumeAutomation(sequenceId, trackId, 2.0, 1.0); // Crescendo to 100%
```

### Playback Control

```dart
// Play the sequence
await sequencer.playSequence(sequenceId, loop: true);

// Stop the sequence
await sequencer.stopSequence(sequenceId);

// Set playback position
await sequencer.setPlaybackPosition(sequenceId, 2.0); // Jump to beat 2

// Get current playback position
final position = await sequencer.getPlaybackPosition(sequenceId);
```

### Volume Control

```dart
// Set master volume
await sequencer.setMasterVolume(0.8); // 80% volume

// Set track volume
await sequencer.setTrackVolume(sequenceId, trackId, 0.7); // 70% volume
```

### Cleanup

```dart
// Unload an instrument when no longer needed
await sequencer.unloadInstrument(sfzInstrumentId);

// Delete a sequence when no longer needed
await sequencer.deleteSequence(sequenceId);

// Release all resources when the app is closing
await sequencer.dispose();
```

## Model Classes

The package includes model classes for working with instruments, sequences, tracks, and notes in your Dart code:

- `Instrument`: Represents a loaded instrument
- `Sequence`: Represents a complete music sequence with tracks
- `Track`: Represents a track in a sequence with notes and automation
- `Note`: Represents a note event with timing and velocity
- `VolumeAutomation`: Represents a volume automation point

## Example App

The package includes a comprehensive example app that demonstrates all the features of the plugin. See the [example](example) directory for detailed instructions on how to run the example.

## Implementation Details

This plugin is implemented using platform channels to communicate between Flutter and native code:

- Android: Native implementation uses sfizz for SFZ playback and Android's AudioTrack API
- iOS: Native implementation uses sfizz with AVAudioEngine and support for AudioUnit instruments

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Development Plan

Below is the original development plan for this project:

<details>
<summary>Click to expand development plan</summary>

Package Creation Overview
Creating a package like flutter_sequencer involves building a Flutter plugin that handles music sequencing with native audio processing on both iOS and Android. This will allow users to set up sampler instruments, create multi-track sequences, and manage looping and volume automations, similar to the original package.
Functionality and Features
The new package should mirror flutter_sequencer by supporting:
Loading and playing sampler instruments using SFZ files via the sfizz library.

Creating and playing multi-track sequences of notes.

Implementing looping and volume automation features for dynamic playback.

Supporting SoundFont (SF2) files for additional instrument options.

On iOS, enabling the loading of any AudioUnit instrument for extended compatibility.

Development Approach
The development process will involve:
Setting up a Flutter package with Dart code for the user-facing API and native code for audio processing.

Using platform channels to communicate between Dart and native implementations on Android and iOS.

Ensuring asset path handling for SFZ and sample files, addressing URL encoding issues.

Testing thoroughly on both platforms to ensure performance and compatibility with the latest Flutter version (3.7.0 as of March 13, 2025).

For more details on Flutter package development, visit the official Flutter documentation at Flutter Packages.
Technical Implementation
The implementation will require integrating the sfizz library for SFZ playback, which is a C++ library, into both Android and iOS projects. Android will use audio APIs like AudioTrack, while iOS will leverage AVAudioEngine and support for AudioUnit instruments. This ensures high-performance audio processing, crucial for real-time music sequencing.

</details>

# flutter_multitracker
