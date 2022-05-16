import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

Future<void> benchmark<T>({
  required List<String> args,
  required String name,
  required Future<T> Function() setup,
  required Future<void> Function(T) teardown,
  required FutureOr<void> Function(T) benchmark,
}) async {
  List<int> results = <int>[];
  String? error;

  try {
    final parser = ArgParser();
    parser.addOption('count', abbr: 'n', defaultsTo: '25');
    final argResult = parser.parse(args);

    final count = int.parse(argResult['count']);

    for (var i = 0; i < count; i++) {
      final resource = await setup();
      try {
        final watch = Stopwatch()..start();
        final result = benchmark(resource);
        if (result is Future) {
          await result;
        }
        results.add(watch.elapsedMicroseconds);
      } finally {
        await teardown(resource);
      }
    }
  } catch (e) {
    error = e.toString();
  }

  final result = BenchmarkResult(
    name: name,
    results: results,
    error: error,
  );
  print(jsonEncode(result.toJson()));
  exit(0);
}

class BenchmarkResult {
  final String name;
  final List<int> results;
  final String? error;

  BenchmarkResult({required this.name, required this.results, this.error});

  factory BenchmarkResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkResult(
      name: json['name'] as String,
      results: json['results'].cast<int>(),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'results': results,
      'error': error,
    };
  }

  BenchmarkResult skip(int count) {
    return BenchmarkResult(
      name: name,
      results: results.sublist(count),
      error: error,
    );
  }
}
