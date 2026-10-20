import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class OptimServeSession with WidgetsBindingObserver {
  static const _methods = MethodChannel('optimserve/methods');
  static const _events = EventChannel('optimserve/events');
  static bool _owned = false;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;
  OptimServeSession._();

  static Future<OptimServeSession> create({required String appKey, required String appName, required String appId, void Function(Map<String, dynamic>)? onEvent}) async {
    if (_owned) throw StateError('Close the other OptimServe session first.');
    if (!RegExp(r'^opa_[a-fA-F0-9]{32}_[a-fA-F0-9]{64}$').hasMatch(appKey) || appName.trim().isEmpty || appName.length > 80 || !RegExp(r'^[A-Za-z0-9._-]{1,160}$').hasMatch(appId)) throw ArgumentError('Copy your App Key, app name and package/bundle App ID from OptimServe.');
    _owned = true;
    final session = OptimServeSession._();
    try {
      await _methods.invokeMethod<void>('configure', {'key': appKey, 'name': appName, 'id': appId});
      session._subscription = _events.receiveBroadcastStream().listen((dynamic raw) {
        if (session._closed) return;
        try {
          final event = _map(raw);
          if (event['type'] == 'url') {onEvent?.call({..._map(event['playback'] ?? event), 'type': 'url'});}
          else if (event['type'] == 'stats') {onEvent?.call(event);}
        } catch (_) { /* Customer callbacks do not control accounting. */ }
      }, onError: (Object error) {});
      WidgetsBinding.instance.addObserver(session);
      session.didChangeAppLifecycleState(WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.inactive);
      return session;
    } catch (_) { _owned = false; try { await _methods.invokeMethod<void>('close'); } catch (_) {} rethrow; }
  }
  static Map<String, dynamic> _map(dynamic raw) => Map<String, dynamic>.from(raw is String ? jsonDecode(raw) as Map : raw as Map);
  Future<dynamic> _call(String name, [Map<String, dynamic>? args]) {
    if (_closed) throw StateError('OptimServe session is closed.');
    return _methods.invokeMethod<dynamic>(name, args);
  }
  Future<Map<String, dynamic>> prepare(String stream, {String? streamId}) async {
    final uri = Uri.tryParse(stream);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasFragment || stream.length > 2048 || streamId != null && !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$').hasMatch(streamId)) throw ArgumentError('Use an HTTPS media URL and valid optional Stream ID.');
    return _map(await _call('prepare', {'url': stream, 'streamId': streamId}));
  }
  Future<void> updatePlayback(String state, {double bufferedMs = 0, double positionMs = 0}) async {
    if (!['playing', 'paused', 'buffering', 'stopped'].contains(state) || [bufferedMs, positionMs].any((n) => !n.isFinite || n < 0)) throw ArgumentError('Invalid playback state or position.');
    await _call('updatePlayback', {'state': state, 'buffered': bufferedMs, 'position': positionMs});
  }
  Future<void> setBackground(bool value) async { await _call('setBackground', {'value': value}); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (!_closed) { unawaited(setBackground(state != AppLifecycleState.resumed).catchError((Object _) {})); } }
  Future<Map<String, dynamic>> snapshot() async => _map(await _call('snapshot'));
  Future<void> stop() async { await _call('stop'); }
  Future<void> close() async {
    if (_closed) return;
    _closed = true; WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    try { await _methods.invokeMethod<void>('close'); } finally { _owned = false; }
  }
}
