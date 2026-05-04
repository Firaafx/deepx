// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<bool> toggleBrowserFullscreen() async {
  if (html.document.fullscreenElement != null) {
    html.document.exitFullscreen();
    return true;
  }
  final html.Element? root = html.document.documentElement;
  if (root == null) return false;
  root.requestFullscreen();
  return true;
}
