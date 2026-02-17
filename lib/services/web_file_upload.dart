// ignore_for_file: avoid_web_libraries_in_flutter,deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class PickedDeviceFile {
  PickedDeviceFile({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final Uint8List bytes;
}

Future<PickedDeviceFile?> pickDeviceFile({
  String accept = '*/*',
}) async {
  if (!kIsWeb) return null;

  final html.FileUploadInputElement input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false
    ..style.display = 'none';

  html.document.body?.append(input);

  final Completer<PickedDeviceFile?> completer = Completer<PickedDeviceFile?>();
  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;
  bool didReceiveChange = false;
  Timer? focusCancelTimer;

  Future<void> completeOnce(PickedDeviceFile? value) async {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  Future<void> readFile(html.File file) async {
    final html.FileReader reader = html.FileReader();
    final Completer<Object?> readCompleter = Completer<Object?>();
    late final StreamSubscription<html.ProgressEvent> loadEndSub;
    late final StreamSubscription<html.ProgressEvent> errorSub;
    loadEndSub = reader.onLoadEnd.listen((_) {
      if (!readCompleter.isCompleted) {
        readCompleter.complete(reader.result);
      }
    });
    errorSub = reader.onError.listen((_) {
      if (!readCompleter.isCompleted) {
        readCompleter.complete(null);
      }
    });
    reader.readAsArrayBuffer(file);
    final Object? result = await readCompleter.future
        .timeout(const Duration(seconds: 45), onTimeout: () => null);
    await loadEndSub.cancel();
    await errorSub.cancel();

    if (result is! ByteBuffer) {
      await completeOnce(null);
      return;
    }

    await completeOnce(
      PickedDeviceFile(
        name: file.name,
        contentType: file.type.isEmpty ? 'application/octet-stream' : file.type,
        bytes: Uint8List.view(result),
      ),
    );
  }

  changeSub = input.onChange.listen((_) async {
    didReceiveChange = true;
    final html.File? file = (input.files != null && input.files!.isNotEmpty)
        ? input.files!.first
        : null;
    if (file == null) {
      await completeOnce(null);
      return;
    }
    await readFile(file);
  });

  focusSub = html.window.onFocus.listen((_) {
    focusCancelTimer?.cancel();
    focusCancelTimer = Timer(const Duration(milliseconds: 900), () async {
      if (completer.isCompleted) return;
      final hasSelection = input.files != null && input.files!.isNotEmpty;
      if (!didReceiveChange && !hasSelection) {
        await completeOnce(null);
      }
    });
  });

  input.click();

  PickedDeviceFile? result;
  try {
    result = await completer.future
        .timeout(const Duration(seconds: 45), onTimeout: () => null);
  } finally {
    focusCancelTimer?.cancel();
    await changeSub.cancel();
    await focusSub.cancel();
    input.remove();
  }
  return result;
}
