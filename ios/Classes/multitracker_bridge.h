#ifndef MULTITRACKER_BRIDGE_H
#define MULTITRACKER_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Callback handling
void* registerDartCallbackPort(int64_t port);

// Audio engine functions
bool initAudioEngine(int sampleRate);
bool startAudioEngine();
bool stopAudioEngine();
bool cleanup();
bool setMasterVolume(float volume);

// Instrument functions
int loadInstrumentFromSFZ(const char* sfzPath);
int loadInstrumentFromSF2(const char* sf2Path, int preset, int bank);
bool unloadInstrument(int instrumentId);

// Note functions
bool sendNoteOn(int instrumentId, int noteNumber, int velocity);
bool sendNoteOff(int instrumentId, int noteNumber);

// Sequence functions
int createSequence(float bpm, int timeSignatureNumerator, int timeSignatureDenominator);
bool deleteSequence(int sequenceId);
int addTrack(int sequenceId, int instrumentId);
bool addNote(int sequenceId, int trackId, int noteNumber, int velocity, float startBeat, float durationBeats);
bool playSequence(int sequenceId, bool loop);
bool stopSequence(int sequenceId);
bool setPlaybackPosition(int sequenceId, float beat);
float getPlaybackPosition(int sequenceId);
bool setTrackVolume(int sequenceId, int trackId, float volume);

#ifdef __cplusplus
}
#endif

#endif // MULTITRACKER_BRIDGE_H 