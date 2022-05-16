import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:isar_bench/benchmark.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final parser = ArgParser();
  parser.addOption('count', abbr: 'n', defaultsTo: '50');
  parser.addOption('skip', abbr: 's', defaultsTo: '10');
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

  final result = <String, Map<String, BenchmarkResult>>{};

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
      result[ref] = {
        for (var r in skippedResults) r.name: r,
      };
    } finally {
      if (ref != 'current') {
        Directory('isar').deleteSync(recursive: true);
      }
    }
  }

  print(formatBenchmarks(result));
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

String formatBenchmarks(Map<String, Map<String, BenchmarkResult>> results) {
  final current = results['current']!;
  final refs = results.keys.where((e) => e != 'current').toList()..sort();
  final benchmarks = current.values.toList()..sort();

  var html =
      '<table><thead><tr><th>Benchmark</th><th>Metric</th><th>Current</th>';
  for (var ref in refs) {
    html += '<th>$ref</th>';
  }
  html += '</thead><tbody>';

  for (var benchmark in benchmarks) {
    final currentAverage = current[benchmark.name]!.averageTime;
    html += '<tr><td rowspan="2">${benchmark.name}</td><td>Average</td>'
        '<td>${_formatTime(currentAverage)}</td>';
    for (var ref in refs) {
      final resultAverage = results[ref]![benchmark.name]!.averageTime;
      html += '<td>${_formatTime(resultAverage, currentAverage)}</td>';
    }
    html += '</tr>';

    final currentMax = current[benchmark.name]!.maxTime;
    html += '<tr><td>Max</td><td>${_formatTime(currentMax)}</td>';
    for (var ref in refs) {
      final resultMax = results[ref]![benchmark.name]!.averageTime;
      html += '<td>${_formatTime(resultMax, currentMax)}</td>';
    }
    html += '</tr>';
  }

  html += '</tbody></table>';

  return html;
}

String _formatTime(int time, [int? current]) {
  final timeStr = (time.toDouble() / 1000).toStringAsFixed(1);
  if (current != null) {
    final diff = 100 - ((current.toDouble() / time) * 100).round();
    return '${timeStr}ms (${diff > 0 ? '+' : ''}$diff%)';
  } else {
    return '${timeStr}ms';
  }
}
