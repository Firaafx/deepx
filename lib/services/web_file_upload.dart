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
  StreamSubscription<html.Event>? inputSub;
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

    Uint8List? bytes;
    if (result is ByteBuffer) {
      bytes = Uint8List.view(result);
    } else if (result is Uint8List) {
      bytes = result;
    } else if (result is List<int>) {
      bytes = Uint8List.fromList(result);
    }
    if (bytes == null || bytes.isEmpty) {
      await completeOnce(null);
      return;
    }

    await completeOnce(
      PickedDeviceFile(
        name: file.name,
        contentType: file.type.isEmpty ? 'application/octet-stream' : file.type,
        bytes: bytes,
      ),
    );
  }

  Future<void> tryReadSelection() async {
    final html.File? file = (input.files != null && input.files!.isNotEmpty)
        ? input.files!.first
        : null;
    if (file == null) {
      await completeOnce(null);
      return;
    }
    await readFile(file);
  }

  changeSub = input.onChange.listen((_) async {
    didReceiveChange = true;
    focusCancelTimer?.cancel();
    await tryReadSelection();
  });

  inputSub = input.onInput.listen((_) async {
    if (didReceiveChange) return;
    if (completer.isCompleted) return;
    if (input.files == null || input.files!.isEmpty) return;
    didReceiveChange = true;
    focusCancelTimer?.cancel();
    await tryReadSelection();
  });

  focusSub = html.window.onFocus.listen((_) {
    focusCancelTimer?.cancel();
    focusCancelTimer = Timer(const Duration(milliseconds: 2800), () async {
      if (completer.isCompleted) return;
      final hasSelection = input.files != null && input.files!.isNotEmpty;
      if (hasSelection) {
        didReceiveChange = true;
        await tryReadSelection();
        return;
      }
      if (!didReceiveChange) {
        // Browsers can lag file selection propagation after focus returns.
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (completer.isCompleted) return;
        final retryHasSelection = input.files != null && input.files!.isNotEmpty;
        if (retryHasSelection) {
          didReceiveChange = true;
          await tryReadSelection();
          return;
        }
        await completeOnce(null);
      }
    });
  });

  input.value = '';
  input.click();

  PickedDeviceFile? result;
  try {
    result = await completer.future
        .timeout(const Duration(seconds: 45), onTimeout: () => null);
  } finally {
    focusCancelTimer?.cancel();
    await changeSub.cancel();
    await inputSub.cancel();
    await focusSub.cancel();
    input.remove();
  }
  return result;
}
