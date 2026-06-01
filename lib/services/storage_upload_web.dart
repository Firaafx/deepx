// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

typedef UploadProgressCallback = void Function(double progress);

String _encodeStoragePath(String path) {
  return path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
}

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
  final String cleanUrl = supabaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
  if (cleanUrl.isEmpty ||
      anonKey.trim().isEmpty ||
      accessToken.trim().isEmpty) {
    return false;
  }

  final Completer<bool> completer = Completer<bool>();
  final html.HttpRequest request = html.HttpRequest();
  final String objectUrl =
      '$cleanUrl/storage/v1/object/$bucket/${_encodeStoragePath(path)}';

  StreamSubscription<html.ProgressEvent>? progressSub;
  StreamSubscription<html.ProgressEvent>? loadSub;
  StreamSubscription<html.ProgressEvent>? errorSub;
  StreamSubscription<html.ProgressEvent>? abortSub;

  Future<void> cleanup() async {
    await progressSub?.cancel();
    await loadSub?.cancel();
    await errorSub?.cancel();
    await abortSub?.cancel();
  }

  void completeError(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }

  progressSub = request.upload.onProgress.listen((event) {
    final int total = event.total ?? 0;
    final int loaded = event.loaded ?? 0;
    if (total <= 0) return;
    onProgress?.call((loaded / total).clamp(0, 1).toDouble());
  });
  loadSub = request.onLoad.listen((_) {
    if (request.status != null &&
        request.status! >= 200 &&
        request.status! < 300) {
      onProgress?.call(1);
      if (!completer.isCompleted) completer.complete(true);
      return;
    }
    completeError(
      Exception(
        'Upload failed in storage (${request.status}): ${request.responseText}',
      ),
    );
  });
  errorSub = request.onError.listen((_) {
    completeError(Exception('Upload failed in storage: network error.'));
  });
  abortSub = request.onAbort.listen((_) {
    completeError(Exception('Upload cancelled.'));
  });

  request
    ..open('POST', objectUrl, async: true)
    ..setRequestHeader('apikey', anonKey)
    ..setRequestHeader('authorization', 'Bearer $accessToken')
    ..setRequestHeader(
      'content-type',
      contentType.trim().isEmpty ? 'application/octet-stream' : contentType,
    )
    ..setRequestHeader('x-upsert', 'true');

  onProgress?.call(0);
  request.send(html.Blob(<Object>[bytes]));

  try {
    return await completer.future.timeout(
      const Duration(minutes: 30),
      onTimeout: () {
        request.abort();
        throw TimeoutException('Upload timed out.');
      },
    );
  } finally {
    await cleanup();
  }
}
