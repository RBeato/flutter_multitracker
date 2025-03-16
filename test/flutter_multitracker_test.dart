import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_multitracker/flutter_multitracker.dart';
import 'package:flutter_multitracker/flutter_multitracker_platform_interface.dart';
import 'package:flutter_multitracker/flutter_multitracker_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterMultitrackerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterMultitrackerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterMultitrackerPlatform initialPlatform = FlutterMultitrackerPlatform.instance;

  test('$MethodChannelFlutterMultitracker is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterMultitracker>());
  });

  test('getPlatformVersion', () async {
    FlutterMultitracker flutterMultitrackerPlugin = FlutterMultitracker();
    MockFlutterMultitrackerPlatform fakePlatform = MockFlutterMultitrackerPlatform();
    FlutterMultitrackerPlatform.instance = fakePlatform;

    expect(await flutterMultitrackerPlugin.getPlatformVersion(), '42');
  });
}
