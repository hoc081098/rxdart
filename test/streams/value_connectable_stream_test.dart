import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

class MockStream<T> extends Mock implements Stream<T> {}

void main() {
  group('ValueConnectableStream', () {
    test('should not emit before connecting', () {
      final stream = MockStream<int>();
      final connectableStream = ValueConnectableStream(stream);

      when(stream.listen(any, onError: anyNamed('onError')))
          .thenReturn(Stream<int>.fromIterable(const [1, 2, 3]).listen(null));

      verifyNever(stream.listen(any, onError: anyNamed('onError')));

      connectableStream.connect();

      verify(stream.listen(any, onError: anyNamed('onError')));
    });

    test('should begin emitting items after connection', () {
      final ConnectableStream<int> stream =
          ValueConnectableStream<int>(Stream<int>.fromIterable(<int>[1, 2, 3]));

      stream.connect();

      expect(stream, emitsInOrder(<int>[1, 2, 3]));
    });

    test('stops emitting after the connection is cancelled', () async {
      final ConnectableStream<int> stream =
          Stream<int>.fromIterable(<int>[1, 2, 3]).publishValue();

      stream.connect()..cancel(); // ignore: unawaited_futures

      expect(stream, neverEmits(anything));
    });

    test('multicasts a single-subscription stream', () async {
      final stream = ValueConnectableStream(
        Stream.fromIterable(const [1, 2, 3]),
      ).autoConnect();

      expect(stream, emitsInOrder(<int>[1, 2, 3]));
      expect(stream, emitsInOrder(<int>[1, 2, 3]));
      expect(stream, emitsInOrder(<int>[1, 2, 3]));
    });

    test('can multicast streams', () async {
      final stream = Stream.fromIterable(const [1, 2, 3]).publishValue();

      stream.connect();

      expect(stream, emitsInOrder(<int>[1, 2, 3]));
      expect(stream, emitsInOrder(<int>[1, 2, 3]));
      expect(stream, emitsInOrder(<int>[1, 2, 3]));
    });

    test('refcount automatically connects', () async {
      final stream = Stream.fromIterable(const [1, 2, 3]).shareValue();

      expect(stream, emitsInOrder(const <int>[1, 2, 3]));
      expect(stream, emitsInOrder(const <int>[1, 2, 3]));
      expect(stream, emitsInOrder(const <int>[1, 2, 3]));
    });

    test('provide a function to autoconnect that stops listening', () async {
      final stream = Stream.fromIterable(const [1, 2, 3])
          .publishValue()
          .autoConnect(connection: (subscription) => subscription.cancel());

      expect(await stream.isEmpty, true);
    });

    test('provides access to the latest value', () async {
      const items = [1, 2, 3];
      var count = 0;
      final stream = Stream.fromIterable(const [1, 2, 3]).shareValue();

      stream.listen(expectAsync1((data) {
        expect(data, items[count]);
        count++;
        if (count == items.length) {
          expect(stream.value, 3);
        }
      }, count: items.length));
    });

    test('provides access to the latest value with seeded value', () async {
      const items = [1, 2, 3];
      var count = 0;
      final stream = Stream.fromIterable(const [1, 2, 3]).shareValueSeeded(0);

      expect(stream.value, 0);

      stream.listen(expectAsync1((data) {
        expect(data, items[count]);
        count++;
        if (count == items.length) {
          expect(stream.value, 3);
        }
      }, count: items.length));
    });
  });
}
