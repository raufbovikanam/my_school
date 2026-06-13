import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider? imageFromPath(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  final file = File(path);
  if (file.existsSync()) return FileImage(file);
  return null;
}
