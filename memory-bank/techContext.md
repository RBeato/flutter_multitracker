# Technical Context

## Technologies Used

### Programming Languages
- **Dart**: For the plugin API and Flutter integration
- **Kotlin**: For Android platform implementation
- **Swift**: For iOS platform implementation
- **C++**: For cross-platform audio engine implementation and FFI bindings
- **Objective-C**: For bridging Swift and C++ on iOS

### Frameworks and Libraries
- **Flutter**: ≥3.24.0 required for compatibility with latest FFI features
- **sfizz**: C++ library for SFZ instrument playback
- **sf2cute**: C++ library for SF2 instrument playback
- **FFI**: Dart Foreign Function Interface for direct native code access
- **path_provider**: For accessing file system paths across platforms
- **plugin_platform_interface**: For defining the plugin's platform interface

### Audio Technologies
- **SFZ Format**: Text-based sample format specification
- **SF2 Format**: SoundFont format for sample-based instruments
- **OpenSL ES**: Android low-level audio API
- **AudioUnit**: iOS audio processing framework
- **AVAudioEngine**: iOS high-level audio framework

## Development Setup

### Flutter Requirements
- Flutter SDK ≥3.24.0
- Dart SDK ≥3.3.0

### Android Requirements
- Android SDK ≥23 (Android 6.0)
- NDK r21e or higher
- CMake 3.18.1 or higher
- Gradle 7.5 or higher

### iOS Requirements
- iOS 11.0 or higher
- Xcode 14.0 or higher
- CocoaPods 1.11.0 or higher

### C++ Requirements
- C++17 support
- CMake 3.18.1 or higher

## Technical Constraints

### Performance Constraints
- **Low Latency**: Audio processing must have minimal latency (<10ms)
- **CPU Usage**: Must be efficient to avoid battery drain
- **Memory Usage**: Sample management must be memory-efficient
- **Thread Safety**: Audio processing must be isolated from UI thread

### Platform Constraints
- **iOS Audio**: Must adhere to iOS audio session guidelines
- **Android Audio**: Must account for device fragmentation in audio capabilities
- **Plugin Lifecycle**: Must handle app lifecycle events properly

### FFI Constraints
- **Memory Management**: Careful management of memory shared between Dart and native code
- **API Design**: FFI APIs must be carefully designed for performance and safety
- **Thread Handling**: Must ensure proper thread synchronization with FFI calls

## Dependencies

### Core Dependencies
- **sfizz**: C++ library for SFZ instrument playback
- **sf2cute**: C++ library for SF2 instrument playback
- **plugin_platform_interface**: For defining the plugin platform interface
- **ffi**: For Dart FFI support
- **path_provider**: For accessing platform-specific directories

### Dev Dependencies
- **ffigen**: For generating Dart FFI bindings from C headers
- **build_runner**: For running code generation tasks
- **mockito**: For mocking in tests
- **test**: For unit testing

## Deployment

### Distribution Channels
- **pub.dev**: For distributing the Flutter plugin
- **Github**: For source code and releases

### Package Structure
- **Federated Plugin**: Following Flutter federated plugin structure
- **Native Libraries**: Properly packaged for each platform

### Versioning
- **Semantic Versioning**: Following semver for package releases

## Optimization Techniques

### Memory Optimization
- **Sample Streaming**: Loading samples on-demand rather than all at once
- **Reference Counting**: For proper resource management
- **Caching**: Smart caching of frequently used samples

### Performance Optimization
- **Lock-free Algorithms**: For audio thread communication
- **SIMD Instructions**: For audio processing where applicable
- **Pre-computation**: Where possible to reduce real-time computation

### Threading Optimization
- **Real-time Audio Thread**: For uninterrupted audio processing
- **Worker Threads**: For loading and processing samples
- **Main Thread**: For UI updates and non-critical operations 