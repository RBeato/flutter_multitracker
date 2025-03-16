import Flutter
import UIKit
import AVFoundation

public class FlutterMultitrackerPlugin: NSObject, FlutterPlugin {
  // Audio engine initialized flag
  private var isAudioEngineInitialized = false
  
  // Default audio settings
  private let defaultSampleRate = 44100
  private let defaultFramesPerBuffer = 512
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_multitracker", binaryMessenger: registrar.messenger())
    let instance = FlutterMultitrackerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
      
    case "initialize":
      let args = call.arguments as? [String: Any]
      let sampleRate = args?["sampleRate"] as? Int ?? defaultSampleRate
      let framesPerBuffer = args?["framesPerBuffer"] as? Int ?? defaultFramesPerBuffer
      
      do {
        // Set audio session
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        
        // Initialize audio engine
        if initAudioEngine(Int32(sampleRate), Int32(framesPerBuffer)) {
          isAudioEngineInitialized = true
          startAudioEngine()
          result(true)
        } else {
          result(FlutterError(code: "INIT_FAILED", message: "Failed to initialize audio engine", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception initializing audio engine: \(error.localizedDescription)", details: nil))
      }
      
    case "loadInstrumentFromSFZ":
      guard let args = call.arguments as? [String: Any],
            let sfzPath = args["sfzPath"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "SFZ path is required", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let instrumentId = loadSFZInstrument(sfzPath)
        if instrumentId >= 0 {
          result(instrumentId)
        } else {
          result(FlutterError(code: "LOAD_FAILED", message: "Failed to load SFZ instrument", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception loading SFZ: \(error.localizedDescription)", details: nil))
      }
      
    case "loadInstrumentFromSF2":
      guard let args = call.arguments as? [String: Any],
            let sf2Path = args["sf2Path"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "SF2 path is required", details: nil))
        return
      }
      
      let preset = args["preset"] as? Int ?? 0
      let bank = args["bank"] as? Int ?? 0
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let instrumentId = loadSF2Instrument(sf2Path, Int32(preset), Int32(bank))
        if instrumentId >= 0 {
          result(instrumentId)
        } else {
          result(FlutterError(code: "LOAD_FAILED", message: "Failed to load SF2 instrument", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception loading SF2: \(error.localizedDescription)", details: nil))
      }
      
    case "loadAudioUnitInstrument":
      guard let args = call.arguments as? [String: Any],
            let componentDescription = args["componentDescription"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Component description is required", details: nil))
        return
      }
      
      let auPresetPath = args["auPresetPath"] as? String ?? ""
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let instrumentId = loadAudioUnitInstrument(componentDescription, auPresetPath)
        if instrumentId >= 0 {
          result(instrumentId)
        } else {
          result(FlutterError(code: "LOAD_FAILED", message: "Failed to load AudioUnit instrument", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception loading AudioUnit: \(error.localizedDescription)", details: nil))
      }
      
    case "unloadInstrument":
      guard let args = call.arguments as? [String: Any],
            let instrumentId = args["instrumentId"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Instrument ID is required", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let success = unloadInstrument(Int32(instrumentId))
        result(success)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception unloading instrument: \(error.localizedDescription)", details: nil))
      }
      
    case "createSequence":
      guard let args = call.arguments as? [String: Any],
            let bpm = args["bpm"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "BPM is required", details: nil))
        return
      }
      
      let lengthInBeats = args["lengthInBeats"] as? Double ?? 16.0
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let sequenceId = createSequence(bpm, lengthInBeats)
        if sequenceId >= 0 {
          result(sequenceId)
        } else {
          result(FlutterError(code: "CREATE_FAILED", message: "Failed to create sequence", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception creating sequence: \(error.localizedDescription)", details: nil))
      }
      
    case "addTrack":
      guard let args = call.arguments as? [String: Any],
            let sequenceId = args["sequenceId"] as? Int,
            let instrumentId = args["instrumentId"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Sequence ID and Instrument ID are required", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let trackId = addTrack(Int32(sequenceId), Int32(instrumentId))
        if trackId >= 0 {
          result(trackId)
        } else {
          result(FlutterError(code: "ADD_FAILED", message: "Failed to add track", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception adding track: \(error.localizedDescription)", details: nil))
      }
      
    case "addNote":
      guard let args = call.arguments as? [String: Any],
            let sequenceId = args["sequenceId"] as? Int,
            let trackId = args["trackId"] as? Int,
            let noteNumber = args["noteNumber"] as? Int,
            let velocity = args["velocity"] as? Int,
            let startBeat = args["startBeat"] as? Double,
            let durationBeats = args["durationBeats"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required arguments for addNote", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let noteId = addNote(Int32(sequenceId), Int32(trackId), Int32(noteNumber), Int32(velocity), startBeat, durationBeats)
        if noteId >= 0 {
          result(noteId)
        } else {
          result(FlutterError(code: "ADD_FAILED", message: "Failed to add note", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception adding note: \(error.localizedDescription)", details: nil))
      }
      
    case "addVolumeAutomation":
      guard let args = call.arguments as? [String: Any],
            let sequenceId = args["sequenceId"] as? Int,
            let trackId = args["trackId"] as? Int,
            let beat = args["beat"] as? Double,
            let volume = args["volume"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required arguments for addVolumeAutomation", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let automationId = addVolumeAutomation(Int32(sequenceId), Int32(trackId), beat, Float(volume))
        if automationId >= 0 {
          result(automationId)
        } else {
          result(FlutterError(code: "ADD_FAILED", message: "Failed to add volume automation", details: nil))
        }
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception adding volume automation: \(error.localizedDescription)", details: nil))
      }
      
    case "playSequence":
      guard let args = call.arguments as? [String: Any],
            let sequenceId = args["sequenceId"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Sequence ID is required", details: nil))
        return
      }
      
      let loop = args["loop"] as? Bool ?? false
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        setLooping(Int32(sequenceId), loop)
        let success = startPlayback(Int32(sequenceId))
        result(success)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception playing sequence: \(error.localizedDescription)", details: nil))
      }
      
    case "stopSequence":
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let success = stopPlayback()
        result(success)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception stopping sequence: \(error.localizedDescription)", details: nil))
      }
      
    case "deleteSequence":
      guard let args = call.arguments as? [String: Any],
            let sequenceId = args["sequenceId"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Sequence ID is required", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let success = deleteSequence(Int32(sequenceId))
        result(success)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception deleting sequence: \(error.localizedDescription)", details: nil))
      }
      
    case "setPlaybackPosition":
      guard let args = call.arguments as? [String: Any],
            let beat = args["beat"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Beat position is required", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let success = setPlaybackPosition(beat)
        result(success)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception setting playback position: \(error.localizedDescription)", details: nil))
      }
      
    case "getPlaybackPosition":
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let position = getPlaybackPosition()
        result(position)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception getting playback position: \(error.localizedDescription)", details: nil))
      }
      
    case "setMasterVolume":
      guard let args = call.arguments as? [String: Any],
            let volume = args["volume"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Volume is required", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let success = setMasterVolume(Float(volume))
        result(success)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception setting master volume: \(error.localizedDescription)", details: nil))
      }
      
    case "setTrackVolume":
      guard let args = call.arguments as? [String: Any],
            let sequenceId = args["sequenceId"] as? Int,
            let trackId = args["trackId"] as? Int,
            let volume = args["volume"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Sequence ID, Track ID, and volume are required", details: nil))
        return
      }
      
      if !isAudioEngineInitialized {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Audio engine not initialized", details: nil))
        return
      }
      
      do {
        let success = setTrackVolume(Int32(sequenceId), Int32(trackId), Float(volume))
        result(success)
      } catch {
        result(FlutterError(code: "EXCEPTION", message: "Exception setting track volume: \(error.localizedDescription)", details: nil))
      }
      
    case "dispose":
      if isAudioEngineInitialized {
        do {
          stopAudioEngine()
          isAudioEngineInitialized = false
        } catch {
          // Ignore exceptions during cleanup
        }
      }
      
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
