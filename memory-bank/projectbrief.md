# Project Brief: flutter_multitracker

## Overview
flutter_multitracker is an updated version of the flutter_sequencer plugin, designed to work with the latest Flutter versions. This project aims to modernize the original plugin while maintaining its core functionality and extending it with new features and improved architecture.

## Core Requirements
1. Create a fully functional audio sequencing plugin compatible with Flutter ≥3.7.0
2. Support SFZ format instrument playback using the sfizz library
3. Support SoundFont (SF2) format instruments
4. Support iOS AudioUnit instruments
5. Provide robust multi-track sequencing capabilities with precise timing
6. Ensure proper volume automation and control
7. Enable playback control including play, stop, loop, and position setting

## Goals
- Maintain compatibility with both Android and iOS platforms
- Ensure thread-safe native audio engine implementation
- Provide a clean, intuitive API for Flutter developers
- Address known issues from the original flutter_sequencer plugin
- Optimize performance for modern devices
- Follow current Flutter plugin development best practices
- Add comprehensive documentation and examples

## Project Scope
This project involves:
1. Studying the original flutter_sequencer plugin architecture
2. Re-implementing the platform-specific code for both Android and iOS
3. Creating a unified Dart API for the plugin
4. Testing with various instrument formats and sequencing scenarios
5. Documenting usage and providing example applications
6. Publishing the package to pub.dev

## Success Criteria
1. All core functionalities of the original plugin are preserved
2. The plugin works reliably on the latest Flutter/Dart versions
3. Performance is equal to or better than the original
4. API is well-documented and easy to use
5. Example applications demonstrate all key features 