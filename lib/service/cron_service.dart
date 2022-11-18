import 'dart:convert';
import 'dart:io';

import 'package:cron/cron.dart';
import 'package:hive/hive.dart';
import 'package:lucifer/lucifer.dart';
import 'package:uuid/uuid.dart';

final cron = Cron();
final uuid = Uuid();
late final BoxCollection collection;
late final CollectionBox cronBox;
late final CollectionBox executionBox;

Map<String, dynamic> inMemoryCron = <String, dynamic>{};

void startDemonSchedule() async {
  var aes =
      env('AES_CIPHER').toString().split(',').map((e) => int.parse(e)).toList();

  collection = await BoxCollection.open(
    'CronBoxDb',
    {'crons', 'executions'},
    path: env('DB_PATH'),
    key: HiveAesCipher(aes),
  );
  cronBox = await collection.openBox<Map>('crons');
  executionBox = await collection.openBox<Map>('executions');
  // load cron from db
  _loadAllCron();
}

void addCron(Map c) async {
  var id = uuid.v1();
  await cronBox.put(id, c);
  _runCron(id);
}

void _loadAllCron() async {
  var lst = await cronBox.getAllValues();
  // foreach cron
  lst.forEach((key, value) async {
    _runCron(key);
  });
}

void _runCron(String i) async {
  var c = await cronBox.get(i);
  // ignore: prefer_typing_uninitialized_variables
  var s;
  try {
    s = cron.schedule(Schedule.parse(c['schedule']), () async {
      var id = uuid.v1();
      // insert execution
      executionBox.put('start-' + id, {
        'cronId': i,
        'cronName': c["name"],
        'name': 'start',
        'date': DateTime.now().toString(),
        'code': "",
      });
      // run schedule
      try {
        List<String> params = [];
        if (c['params'].isNotEmpty) {
          params.addAll(c['params'].toString().split(' '));
        }
        if (c['script'].isNotEmpty) {
          params.add(c['script'].toString());
        }
        final Process process = await Process.start(c['app'], params);
        final List<int> output = <int>[];
        process.stderr.listen(
          (event) {
            stdout.add(event);
            output.addAll(event);
          },
          onDone: () async {
            executionBox.put('end-' + id, {
              'cronId': i,
              'cronName': c["name"],
              'name': 'end: ' + utf8.decoder.convert(output),
              'date': DateTime.now().toString(),
              'code': await process.exitCode,
            });
          },
        );
        process.stdout.listen((List<int> event) {
          stdout.add(event);
          output.addAll(event);
        }, onDone: () async {
          executionBox.put('end-' + id, {
            'cronId': i,
            'cronName': c["name"],
            'name': 'end: ' + utf8.decoder.convert(output),
            'date': DateTime.now().toString(),
            'code': await process.exitCode,
          });
        });
      } catch (e) {
        executionBox.put('error-' + id, {
          'cronId': i,
          'cronName': c["name"],
          'name': 'error',
          'date': DateTime.now().toString(),
          'code': e.toString(),
        });
      }
    });
  } catch (e) {
    Logger().d(e);
  }

  inMemoryCron[i] = {
    'scheduleTask': s ?? "",
    'name': c["name"],
    'actif': c["actif"],
    'schedule': c["schedule"],
  };
}

Future<Map<String, dynamic>> getAllExecutions() {
  return executionBox.getAllValues();
}

Map<String, dynamic> getAllJobs() {
  return inMemoryCron;
}

Future<dynamic> getJobForEdit(key) {
  return cronBox.get(key);
}