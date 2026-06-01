import 'dart:typed_data';

typedef UploadProgressCallback = void Function(double progress);

Future<bool> uploadStorageBytesWithProgress({
  required String supabaseUrl,
  required String anonKey,
  required String accessToken,
  required String bucket,
  required String path,
  required Uint8List bytes,
  required String contentType,
  UploadProgressCallback? onProgress,
}) async {
  return false;
}
