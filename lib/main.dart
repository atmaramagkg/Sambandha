import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'app.dart';

void main() {
  // The mobile sqflite plugin registers its own factory. Desktop needs the
  // FFI implementation, so initialize it before any database provider runs.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    ffi.sqfliteFfiInit();
    databaseFactory = ffi.databaseFactoryFfi;
  }

  runApp(const ProviderScope(child: VrajaMandalaApp()));
}
