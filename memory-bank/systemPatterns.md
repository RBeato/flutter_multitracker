# System Patterns

## System Architecture

flutter_multitracker follows a layered architecture pattern with FFI for performance:

```
┌───────────────────────────────────────────┐
│             Flutter App                   │
└───────────────┬───────────────────────────┘
                │
┌───────────────▼───────────────────────────┐
│           Dart API Layer                  │
│  (flutter_multitracker.dart)              │
└───────────────┬───────────────────────────┘
                │
┌───────────────▼───────────────────────────┐
│         Platform Interface               │
│  (flutter_multitracker_platform_interface.dart) │
└─┬─────────────────────────────────────────┘
  │
  ├─────────────────┐
  │                 │
┌─▼─────────────┐ ┌─▼─────────────┐
│ Method Channel│ │ FFI           │
│ Implementation│ │Implementation │
└─┬─────────────┘ └───┬───────────┘
  │                   │ Direct memory access
  │ IPC               │
┌─▼─────────────┐ ┌───▼───────────┐
│ Android Native│ │ iOS Native    │
│ (Kotlin/Java) │ │ (Swift/ObjC)  │
└─┬─────────────┘ └─┬─────────────┘
  │                 │
┌─▼─────────────┐ ┌─▼─────────────┐
│ C++ Audio     │ │ C++ Audio     │
│ Engine        │ │ Engine        │
└───────────────┘ └───────────────┘
```

## Key Technical Decisions

1. **FFI Over Method Channels**: 
   - Using Dart FFI for direct native code access instead of Method Channels
   - Eliminating serialization/deserialization overhead for performance-critical audio operations
   - Maintaining Method Channels for non-performance-critical operations

2. **Dedicated Audio Thread Management**:
   - Implementing robust audio thread handling separate from the main UI thread
   - Using proper synchronization mechanisms (mutexes, atomics) to prevent race conditions
   - Callback handling between native code and Dart via dedicated message passing

3. **Native Audio Implementation**:
   - Android: Optimized OpenSL ES implementation for low latency
   - iOS: AVAudioEngine with proper AudioUnit integration
   - Common C++ core for audio processing shared between platforms

4. **Resource Management**:
   - Proper memory management for audio samples with caching
   - Resource cleanup on context switches
   - Memory-efficient instrument loading with on-demand sample management

5. **Plugin Architecture**: 
   - Follows the federated plugin approach recommended by Flutter
   - Implements proper FFI bindings generation
   - Unified C++ core shared between platforms

## Design Patterns in Use

1. **Singleton Pattern**: Main plugin class is a singleton to ensure single audio engine instance.

2. **Factory Pattern**: For creating different types of instruments (SFZ, SF2, AudioUnit).

3. **Builder Pattern**: For constructing complex sequences with multiple tracks and notes.

4. **Observer Pattern**: For playback state changes and position updates.

5. **Command Pattern**: For audio engine operations that may be queued or scheduled.

6. **Repository Pattern**: For managing instrument collections and their resources.

7. **Bridge Pattern**: Connecting Dart API to native implementation through FFI.

## Component Relationships

### Models
- **Instrument**: Represents a loaded instrument with its properties and capabilities
- **Sequence**: Contains multiple tracks and global playback settings
- **Track**: Contains notes and automation data, linked to an instrument
- **Note**: Represents a single note event with timing, pitch, velocity, and duration
- **Automation**: Represents control changes like volume over time

### Native Bridge
- FFI implementation for direct memory access and function calls
- Proper memory management for shared resources
- Callback system for event notifications

### Audio Engine
- Unified C++ core implementation
- Platform-specific audio output implementations
- Thread-safe operation with proper synchronization
- Memory-efficient sample management
- Real-time processing capabilities

### Threading Model
- Main Thread: UI rendering and user interactions
- Audio Thread: Real-time audio processing and scheduling
- Loading Thread: Asynchronous resource loading and processing
- Communication through lock-free queues and atomics

This architecture ensures high performance for audio processing tasks while maintaining a clean, maintainable codebase with clear separation of concerns. 