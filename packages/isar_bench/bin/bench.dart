import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:isar_bench/benchmark.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final parser = ArgParser();
  parser.addOption('count', abbr: 'n', defaultsTo: '20');
  parser.addOption('skip', abbr: 's', defaultsTo: '5');
  parser.addMultiOption('ref', abbr: 'r', defaultsTo: []);
  parser.addMultiOption('benchmark', abbr: 'b', defaultsTo: []);
  parser.addOption(
    'format',
    abbr: 'f',
    defaultsTo: 'txt',
    allowed: ['txt', 'md', 'json'],
  );
  final argResult = parser.parse(args);

  final count = int.parse(argResult['count']);
  final skip = int.parse(argResult['skip']);
  final refs = <String>['current', ...argResult['ref']];

  final selectedBenchmarks = argResult['benchmark'] as List<String>;
  final allBenchmarks = _findAllBenchmarks();

  final benchmarks = selectedBenchmarks.isNotEmpty
      ? selectedBenchmarks.where((e) => allBenchmarks.contains(e)).toList()
      : allBenchmarks;

  final result = <String, List<BenchmarkResult>>{};

  for (var ref in refs) {
    try {
      String? workingDir;
      if (ref != 'current') {
        _run('git', ['clone', 'https://github.com/isar/isar.git']);
        _run('git', ['checkout', ref],
            workingDirectory: Directory('isar').absolute.path);
        workingDir = p.join('isar', 'packages', 'isar_bench');
      }
      final results = _runBenchmarks(benchmarks, count + skip, workingDir);
      final skippedResults = results.map((e) => e.skip(skip)).toList();
      result[ref] = skippedResults;
    } finally {
      Directory('isar').deleteSync(recursive: true);
    }
  }

  print('OK');
}

List<String> _findAllBenchmarks() {
  final benchmarks = <String>[];
  final dir = Directory(p.join('lib', 'benchmarks'));
  for (var file in dir.listSync()) {
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.endsWith('g.dart')) {
      final name = p.basenameWithoutExtension(file.path);
      benchmarks.add(name);
    }
  }
  return benchmarks;
}

String _run(String executable, List<String> arguments,
    {String? workingDirectory}) {
  final process = Process.runSync(executable, arguments,
      workingDirectory: workingDirectory, runInShell: true);
  if (process.exitCode == 0) {
    return process.stdout;
  } else {
    throw process.stderr;
  }
}

List<BenchmarkResult> _runBenchmarks(
    List<String> benchmarks, int count, String? workingDirectory) {
  print('AA: $workingDirectory');
  _run(Platform.executable, ['pub', 'get'], workingDirectory: workingDirectory);
  _run(
    Platform.executable,
    ['pub', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    workingDirectory: workingDirectory,
  );
  final results = <BenchmarkResult>[];
  for (var benchmark in benchmarks) {
    final result = _run(
      Platform.executable,
      [p.join('lib', 'benchmarks', '$benchmark.dart'), '-n', count.toString()],
      workingDirectory: workingDirectory,
    );
    results.add(BenchmarkResult.fromJson(jsonDecode(result)));
  }
  return results;
}
