// ignore_for_file: avoid_web_libraries_in_flutter,deprecated_member_use

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
    ..multiple = false;

  input.click();
  await input.onChange.first;

  final html.File? file = (input.files != null && input.files!.isNotEmpty)
      ? input.files!.first
      : null;
  if (file == null) return null;

  final html.FileReader reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoadEnd.first;

  final Object? result = reader.result;
  if (result is! ByteBuffer) return null;

  return PickedDeviceFile(
    name: file.name,
    contentType: file.type.isEmpty ? 'application/octet-stream' : file.type,
    bytes: Uint8List.view(result),
  );
}
