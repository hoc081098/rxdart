import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

Stream<int> getStream(int n) {}

void main() async {
  test('Rx.windowWhen.first', () async {
    StreamController<int> controller;
    controller = StreamController<int>.broadcast(
      sync: true,
      onListen: () => controller.add(10),
    );
    await controller.stream.windowWhen(() => Stream.value(2)).first;
    expect(true, true);
  });
}
