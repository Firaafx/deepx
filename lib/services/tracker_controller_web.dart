// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

const bool isTrackerSupported = true;

final StreamController<bool> _visibilityController =
    StreamController<bool>.broadcast();
StreamSubscription<html.MessageEvent>? _messageSub;

Stream<bool> get trackerUiVisibilityChanges {
  initializeTrackerController();
  return _visibilityController.stream;
}

void initializeTrackerController() {
  if (_messageSub != null) return;
  _messageSub = html.window.onMessage.listen((event) {
    final data = _normalizedMessageData(event.data);
    if (data is! Map) return;
    final type = data['type'];
    if (type != 'deepx-tracker-state') return;
    final visible = data['uiVisible'];
    if (visible is! bool) return;
    setTrackerFrameInteractive(visible);
    _visibilityController.add(visible);
  });
}

dynamic _normalizedMessageData(dynamic data) {
  if (data is Map) return data;
  if (data is! String) return null;
  try {
    return jsonDecode(data);
  } catch (_) {
    return null;
  }
}

html.IFrameElement? _trackerFrame() {
  final element = html.document.getElementById('deepx-tracker-frame');
  return element is html.IFrameElement ? element : null;
}

void setTrackerFrameInteractive(bool interactive) {
  final frame = _trackerFrame();
  if (frame == null) return;
  frame.style.pointerEvents = interactive ? 'auto' : 'none';
}

void _postTrackerCommand(String command) {
  initializeTrackerController();
  final frame = _trackerFrame();
  frame?.contentWindow?.postMessage(
    <String, String>{
      'type': 'deepx-tracker-command',
      'command': command,
    },
    '*',
  );
}

void showTrackerUi() {
  setTrackerFrameInteractive(true);
  _postTrackerCommand('show-ui');
}

void hideTrackerUi() {
  _postTrackerCommand('hide-ui');
}

void toggleTrackerUi() {
  setTrackerFrameInteractive(true);
  _postTrackerCommand('toggle-ui');
}
