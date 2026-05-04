import 'dart:typed_data';

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
  return null;
}
