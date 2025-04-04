#include <stdint.h>
#include <string>
#include "multitracker_bridge.h"

extern "C" {

// Test initialization function for FFI
int8_t test_init() {
    return 1; // Return 1 for success
}

// Register Dart callback port
void* register_dart_callback_port(int64_t port) {
    return registerDartCallbackPort(port);
}

// Initialize the audio engine
int8_t init_audio_engine(int32_t sampleRate) {
    return initAudioEngine(sampleRate) ? 1 : 0;
}

// Start the audio engine
int8_t start_audio_engine() {
    return startAudioEngine() ? 1 : 0;
}

// Stop the audio engine
int8_t stop_audio_engine() {
    return stopAudioEngine() ? 1 : 0;
}

// Load instrument from SFZ file
int32_t load_instrument_sfz(const char* sfzPath) {
    return loadInstrumentFromSFZ(sfzPath);
}

// Load instrument from SF2 file
int32_t load_instrument_sf2(const char* sf2Path, int32_t preset, int32_t bank) {
    return loadInstrumentFromSF2(sf2Path, preset, bank);
}

// Create a sequence
int32_t create_sequence(float bpm, int32_t timeSignatureNumerator, int32_t timeSignatureDenominator) {
    return createSequence(bpm, timeSignatureNumerator, timeSignatureDenominator);
}

// Add a track to a sequence
int32_t add_track(int32_t sequenceId, int32_t instrumentId) {
    return addTrack(sequenceId, instrumentId);
}

// Add a note to a track
int8_t add_note(int32_t sequenceId, int32_t trackId, int32_t noteNumber, 
               int32_t velocity, float startBeat, float durationBeats) {
    return addNote(sequenceId, trackId, noteNumber, velocity, startBeat, durationBeats) ? 1 : 0;
}

// Play a sequence
int8_t play_sequence(int32_t sequenceId, int8_t loop) {
    return playSequence(sequenceId, loop != 0) ? 1 : 0;
}

// Stop a sequence
int8_t stop_sequence(int32_t sequenceId) {
    return stopSequence(sequenceId) ? 1 : 0;
}

// Delete a sequence
int8_t delete_sequence(int32_t sequenceId) {
    return deleteSequence(sequenceId) ? 1 : 0;
}

// Set playback position
int8_t set_playback_position(int32_t sequenceId, float beat) {
    return setPlaybackPosition(sequenceId, beat) ? 1 : 0;
}

// Get playback position
float get_playback_position(int32_t sequenceId) {
    return getPlaybackPosition(sequenceId);
}

// Set master volume
int8_t set_master_volume(float volume) {
    return setMasterVolume(volume) ? 1 : 0;
}

// Set track volume
int8_t set_track_volume(int32_t sequenceId, int32_t trackId, float volume) {
    return setTrackVolume(sequenceId, trackId, volume) ? 1 : 0;
}

// Send MIDI note on message
int8_t send_note_on(int32_t instrumentId, int32_t noteNumber, int32_t velocity) {
    return sendNoteOn(instrumentId, noteNumber, velocity) ? 1 : 0;
}

// Send MIDI note off message
int8_t send_note_off(int32_t instrumentId, int32_t noteNumber) {
    return sendNoteOff(instrumentId, noteNumber) ? 1 : 0;
}

// Dispose and clean up resources
int8_t dispose() {
    return cleanup() ? 1 : 0;
}

} 