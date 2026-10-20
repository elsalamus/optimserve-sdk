import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimserve/optimserve.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('optimserve/methods');
  const events = MethodChannel('optimserve/events');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final key = 'opa_${'a' * 32}_${'b' * 64}';
  Future<OptimServeSession> create() => OptimServeSession.create(appKey: key, appName: 'Player', appId: 'com.example.player');

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test('failed setup cannot release ownership before native close completes', () async {
    final closing = Completer<void>(), release = Completer<void>();
    var fail = true;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'configure' && fail) throw PlatformException(code: 'setup');
      if (call.method == 'close' && fail) {closing.complete(); await release.future;}
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    final failed = expectLater(create(), throwsA(isA<PlatformException>()));
    await closing.future;
    await expectLater(create(), throwsStateError);
    fail = false; release.complete(); await failed;
    final next = await create(); await next.close();
  });

  test('signed URLs remain intact and close failure still releases ownership', () async {
    final calls = <MethodCall>[];
    var failClose = true;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'prepare') return {'url': call.arguments['url'], 'mode': 'http', 'reason': 'test'};
      if (call.method == 'close' && failClose) throw PlatformException(code: 'close');
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    final session = await create();
    const stream = 'https://media.example/live.m3u8?token=a+b&expiry=7';
    expect((await session.prepare(stream))['url'], stream);
    await expectLater(session.prepare('http://media.example/live.m3u8'), throwsArgumentError);
    await expectLater(session.close(), throwsA(isA<PlatformException>()));
    expect(calls.where((call) => call.method == 'close').length, 1);
    failClose = false;
    final next = await create(); await next.close();
  });
}
