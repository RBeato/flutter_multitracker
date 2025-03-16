#ifndef FlutterMultitrackerPlugin_Bridging_Header_h
#define FlutterMultitrackerPlugin_Bridging_Header_h

// C++ interface for the multitracker plugin
#ifdef __cplusplus
extern "C" {
#endif

// Audio engine functions
bool initAudioEngine(int sampleRate, int framesPerBuffer);
bool startAudioEngine();
bool stopAudioEngine();
bool setMasterVolume(float volume);

// Instrument management
int loadSFZInstrument(const char* sfzPath);
int loadSF2Instrument(const char* sf2Path, int preset, int bank);
int loadAudioUnitInstrument(const char* componentDescription, const char* auPresetPath);
bool unloadInstrument(int instrumentId);

// Sequence management
int createSequence(double tempo, double lengthInBeats);
bool deleteSequence(int sequenceId);

// Track management
int addTrack(int sequenceId, int instrumentId);
bool deleteTrack(int sequenceId, int trackId);

// Note management
int addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startTime, double duration);
bool deleteNote(int sequenceId, int trackId, int noteId);

// Volume automation
int addVolumeAutomation(int sequenceId, int trackId, double time, float volume);
bool deleteVolumeAutomation(int sequenceId, int trackId, int automationId);
bool setTrackVolume(int sequenceId, int trackId, float volume);

// Playback control
bool startPlayback(int sequenceId);
bool stopPlayback();
bool setPlaybackPosition(double positionInBeats);
double getPlaybackPosition();
bool setTempo(int sequenceId, double tempo);
bool setLooping(int sequenceId, bool isLooping);

#ifdef __cplusplus
}
#endif

#endif /* FlutterMultitrackerPlugin_Bridging_Header_h */ 