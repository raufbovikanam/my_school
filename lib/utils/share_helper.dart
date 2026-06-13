import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Builds a safe file name for sharing (never empty, no invalid path chars).
String safeShareFileName(String baseName, {required String extension}) {
  var name = baseName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
  if (name.isEmpty) {
    name = 'progress_chart_${DateTime.now().millisecondsSinceEpoch}';
  }
  final ext = extension.startsWith('.') ? extension : '.$extension';
  return name.endsWith(ext) ? name : '$name$ext';
}

/// Opens the system share sheet (WhatsApp, Drive, etc.) with a file attachment.
///
/// Files are passed in-memory via [XFile.fromData] so Android FileProvider path
/// issues are avoided. Do not pass [text] with files — WhatsApp on Android often
/// drops the attachment when EXTRA_TEXT is set.
Future<void> shareBytes({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  BuildContext? context,
}) async {
  if (bytes.isEmpty) {
    throw Exception('File is empty — nothing to share');
  }

  final xFile = XFile.fromData(
    Uint8List.fromList(bytes),
    mimeType: mimeType,
    name: fileName,
  );

  Rect? origin;
  if (context != null && context.mounted) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      origin = offset & box.size;
    }
  }

  await Share.shareXFiles(
    [xFile],
    sharePositionOrigin: origin,
  );
  // On Android, result is often ShareResultStatus.unavailable even when the
  // chooser opened successfully — do not treat that as failure.
}
