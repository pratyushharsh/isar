import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:isar/isar.dart';
import 'benchmark.dart' as b;
import 'package:path/path.dart' as path;

Future<Isar> openIsar(List<CollectionSchema> schemas) async {
  final dartToolDir = path.join(Directory.current.path, '.dart_tool', 'tmp');
  var random = Random().nextInt(pow(2, 32) as int).toString();

  await Isar.initializeIsarCore(download: true);
  return await Isar.open(
    schemas: schemas,
    directory: dartToolDir,
    name: '${random}_tmp',
  );
}

Future<void> closeIsar(Isar isar) {
  return isar.close(deleteFromDisk: true);
}

Future<void> benchmarkIsar({
  required List<String> args,
  required String name,
  required FutureOr<void> Function(Isar isar) benchmark,
  Future<void> Function(Isar isar)? setup,
  required List<CollectionSchema> schemas,
}) =>
    b.benchmark(
      args: args,
      name: name,
      setup: () async {
        final isar = await openIsar(schemas);
        await setup?.call(isar);
        return isar;
      },
      teardown: closeIsar,
      benchmark: benchmark,
    );
