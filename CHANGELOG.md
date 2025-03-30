# Changelog

## 1.0.3 - 2023-12-17

### Added
- Synthetic TR-808 drum sound generation for Android implementation
  - Implemented realistic bass drum with pitch drop and distortion
  - Added snare drum with tone and noise components
  - Created hi-hat sounds with filtered noise and resonance
  - Added crash and ride cymbal sounds with metallic characteristics
- Synthetic piano sound generation with realistic characteristics
  - Multiple harmonics with proper amplitude relationships
  - Harmonic-specific decay rates for natural piano sound
  - Hammer noise simulation for attack transients
  - String resonance effects for richer sound
  - Note-dependent decay times (longer for lower notes)
- Custom envelope settings for all instruments
- Direct sample data storage in audio engine
- New Dart API method: `loadPianoInstrument()`

### Fixed
- Resolved issues with SF2 instrument loading by implementing synthetic sounds
- Eliminated dependency on external WAV files for instrument sounds
- Fixed audio playback issues when sample files are missing or in unsupported formats

### Improved
- More realistic instrument sounds with proper acoustic characteristics
- Better audio quality for percussion and piano instruments
- Reduced latency by generating sounds directly in memory
- More complete instrument palette for music creation

## 1.0.2 - 2023-12-16

### Fixed
- Improved SF2 instrument loading in Android implementation
- Added support for loading individual drum samples from SF2 directory
- Enhanced sample file discovery with multiple path patterns
- Better fallback mechanism when specific samples are not found
  - Added fallback to piano samples when drum samples are unavailable
  - Only uses sine wave as a last resort
- Enhanced logging for SF2 instrument loading process
- Fixed WAV file format compatibility issues
  - Added support for non-standard WAV formats (including format code 26548)
  - Improved chunk parsing to handle files with unexpected structures
  - Better error recovery when reading incomplete or corrupted WAV files
  - Added fallback to silent samples when data chunk is missing
- Added support for checking multiple directories for samples

### Summary
This release focuses on improving the robustness of audio file loading, particularly for SF2 instruments and WAV files. The changes ensure that the TR-808 drum sounds are properly loaded and played, even when dealing with non-standard file formats or incomplete files. The enhanced error handling and fallback mechanisms provide a more reliable audio experience across different devices and file sources.

## 1.0.1 - 2023-12-15

### Fixed
- SF2 instrument type handling in Android implementation
- Drum sounds now correctly use the TR-808 SF2 soundfont instead of falling back to sine wave
- Instrument type detection for sample-based and SFZ instruments

### Improved
- Audio engine stability and performance
- Documentation for instrument type handling

## 0.1.0 - 2023-07-15

### Added
- Initial release with basic audio synthesis capabilities
- Sine wave instrument generation
- ADSR envelope control
- Basic MIDI note handling (noteOn/noteOff)

## 0.2.0 - 2023-08-01

### Added
- Sample-based instrument support
- WAV file loading
- Multi-track sequencing
- Piano keyboard UI component

### Fixed
- Audio glitches in note playback
- Memory leaks in audio engine

## 0.3.0 - 2023-09-10

### Added
- Sequencer with tempo control
- Loop functionality
- Track management (add/delete)
- Note editing capabilities

### Improved
- Audio engine performance
- UI responsiveness

## 0.4.0 - 2023-10-20

### Added
- TR-808 drum machine interface
- Drum pad UI with animation effects
- Improved piano keyboard with note labels
- Support for loading SF2 soundfonts

### Fixed
- Method channel naming inconsistencies
- Sample loading issues

## 0.0.9 - 2023-07-17

### Added
- SF2 soundfont loading for TR-808 drum sounds
- Enhanced step sequencer interface similar to flutter_sequencer
- Improved drum pad UI with LED indicators
- Track selection interface for multi-track editing

### Improved
- Piano keyboard UI with better visual feedback
- Drum machine interface with TR-808 inspired design
- Overall UI consistency and aesthetics
- Error handling and fallback mechanisms for audio loading

## 1.0.0 - 2023-12-01

### Added
- Complete sequencer UI similar to flutter_sequencer
- Step sequencer for drum patterns
- Transport controls (play, pause, stop)
- Project saving and loading

### Improved
- Overall UI design and user experience
- Documentation and examples
- Performance optimizations

## Future Plans
- Support for more audio formats (MP3, OGG)
- Audio effects (reverb, delay, etc.)
- MIDI device integration
- Audio recording capabilities
- Waveform visualization
