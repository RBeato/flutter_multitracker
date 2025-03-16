# flutter_multitracker Example

This example app demonstrates the capabilities of the `flutter_multitracker` plugin for Flutter, which provides audio sequencing and sampler instrument playback.

## Getting Started

1. Make sure you have Flutter installed and set up properly
2. Clone this repository
3. Run `flutter pub get` in both the root directory and the example directory
4. Connect a device or start an emulator/simulator
5. Run `flutter run` from the `example` directory

## Functionality Demonstrations

The example app demonstrates the following features of the `flutter_multitracker` plugin:

### Instrument Loading

- **SFZ Files**: Load and play sampler instruments using SFZ format with FLAC sample files
- **SF2 Files**: Load and play SoundFont (SF2) format instruments
- **AudioUnit** (iOS only): Load and play system AudioUnit instruments

### Sequencing

- Create a multi-track sequence at a specific BPM and time signature
- Add notes with precise timing, pitch, and velocity
- Control playback (play, stop, loop)
- Set playback position to specific beat locations

### Volume Control

- Adjust master volume for the entire playback engine
- Control individual track volumes
- Automate volume changes over time

## Asset Files

The example includes the following assets for testing:

- `assets/sfz/GMPiano.sfz` - A simple piano definition file
- `assets/sfz/samples/*.flac` - FLAC audio samples for the piano
- `assets/sf2/TR-808.sf2` - A SoundFont file with electronic drum samples
- `assets/sfz/meanquar.scl` - A Scala file for alternative tuning
- `assets/wav/*.wav` - WAV files for direct audio testing

## Troubleshooting

- If you encounter issues with asset loading, ensure the files are properly included in `pubspec.yaml` and the paths are correct.
- iOS simulator doesn't support audio playback with the same level of performance as real devices. For best results, test on a physical iOS device.
- Android emulators may have audio latency issues; physical devices are recommended for testing.
- If SFZ files fail to load, check that both the SFZ file and all referenced samples are correctly extracted to an accessible location.

## Implementation Details

The example app uses a Flutter Material Design interface with:

- Cards for organizing different functional sections
- Buttons for triggering actions
- Sliders for volume control and playback position adjustment
- Status messages for operation feedback

The app properly cleans up resources when disposing to prevent memory leaks.
