import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _assetDb = 'assets/db/vrajamandala.db';
const _assetVersion = 'assets/db/version.txt';
const _versionPrefKey = 'content_version';

/// Platform database folder. On mobile, use the sqflite-provided folder; on
/// desktop, use the user's application support directory.
Future<String> _databaseDir() async {
  if (Platform.isAndroid || Platform.isIOS) return getDatabasesPath();
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'databases');
}

/// Opens the bundled content database.
///
/// The database ships inside the app as an asset. On first launch, and
/// whenever its content version changes (after an app update), it is copied
/// into the app's database folder and opened read-only. User data such as
/// saved items lives elsewhere (SharedPreferences), so replacing this file
/// never loses anything.
Future<Database> openContentDatabase() async {
  final dir = await _databaseDir();
  final dest = p.join(dir, 'vrajamandala.db');
  final prefs = await SharedPreferences.getInstance();
  final assetVersion = (await rootBundle.loadString(_assetVersion)).trim();

  final needsCopy = !await databaseExists(dest) ||
      prefs.getString(_versionPrefKey) != assetVersion;

  if (needsCopy) {
    await Directory(dir).create(recursive: true);
    final data = await rootBundle.load(_assetDb);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(dest).writeAsBytes(bytes, flush: true);
    await prefs.setString(_versionPrefKey, assetVersion);
  }

  return openDatabase(dest, readOnly: true);
}
