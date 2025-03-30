# Technical Context

## Technologies Used

### Programming Languages
- **Dart**: Primary language for the Flutter plugin API and model classes
- **Kotlin**: For Android platform implementation
- **Swift**: For iOS platform implementation
- **C++**: For integrating with the sfizz library

### Frameworks & Libraries
- **Flutter**: Cross-platform UI framework (≥3.7.0)
- **sfizz**: Open-source SFZ playback library for sampler instruments
- **path_provider**: Flutter plugin for accessing device file system paths
- **plugin_platform_interface**: Flutter plugin for defining platform interfaces

### Audio Technologies
- **SFZ Format**: Sample-based instrument definition format
- **SF2 (SoundFont) Format**: Another sample-based instrument format
- **AudioUnit**: iOS audio plugin technology
- **AVAudioEngine**: iOS audio processing framework
- **Android AudioTrack API**: Android audio output API

## Development Setup

### Required Tools
- Flutter SDK (≥3.7.0)
- Android Studio / IntelliJ IDEA / VS Code with Flutter plugins
- Xcode for iOS development
- Android NDK for C++ compilation on Android
- CMake for building native libraries
- Git for version control

### Environment Configuration
- Flutter and Dart SDK installation
- Android SDK setup with NDK components
- iOS development environment with Xcode tools
- sfizz library integration with native builds

### Build Process
- Standard Flutter plugin build process
- Native library compilation for both platforms
- FFI bindings generation for sfizz integration

## Technical Constraints

### Platform Limitations
- **Android**: Minimum SDK version 23 (Android 6.0)
- **iOS**: Minimum iOS version 11.0
- **Audio Latency**: Varies by device and platform
- **Memory Usage**: Sampled instruments can use significant memory

### Performance Considerations
- Real-time audio processing requires low-latency operations
- Large SFZ instruments can consume substantial memory
- Concurrent audio processing and UI updates must be managed carefully
- Battery impact of continuous audio processing

### Security Constraints
- App permissions for audio recording (microphone) may be required
- File system access limited to app-specific directories
- Resource cleanup to prevent memory leaks

## Dependencies

### External Dependencies
- **sfizz library**: For SFZ playback
  - Version: latest stable
  - License: BSD-2-Clause
  - Integration: Static compilation

### Flutter Package Dependencies
- **flutter**: Flutter framework
  - Version: ">=3.7.0"
- **path_provider**: For file path access
  - Version: ^2.1.1
- **path**: For path manipulation utilities
  - Version: ^1.8.3
- **plugin_platform_interface**: For platform interface definition
  - Version: ^2.1.8

### Development Dependencies
- **flutter_test**: For testing
  - Version: SDK package
- **flutter_lints**: For code quality
  - Version: ^5.0.0

## Deployment Considerations

### Package Distribution
- Published on pub.dev
- Versioning follows semantic versioning (SemVer)
- Example application included for demonstration

### Installation Requirements
- Users need to add platform-specific permissions
- iOS: Microphone usage description in Info.plist
- Android: RECORD_AUDIO permission in AndroidManifest.xml 