import 'package:isar/isar.dart';
import 'package:isar_bench/common.dart';

part 'insert_many_sync_2.g.dart';

@Collection()
class User {
  final int id;

  final String name;

  final int age;

  final bool isActive;

  final double balance;

  const User(this.id, this.name, this.age, this.isActive, this.balance);
}

final _users = [
  for (var i = 0; i < 10000; i++)
    User(i, 'name$i', i % 100, i % 2 == 0, i.toDouble()),
];

void main(List<String> args) => benchmarkIsar(
      args: args,
      name: 'Insert Many Sync2',
      benchmark: benchmark,
      schemas: [UserSchema],
    );

void benchmark(Isar isar) {
  isar.writeTxnSync(() {
    isar.users.putAllSync(_users);
  });
}
