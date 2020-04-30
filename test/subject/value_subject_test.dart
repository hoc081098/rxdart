import 'dart:async';

import 'package:pedantic/pedantic.dart';
import 'package:rxdart/src/subjects/value_subject.dart';
import 'package:test/test.dart';

typedef AsyncVoidCallBack = Future<Null> Function();

// ignore_for_file: close_sinks

void main() {
  group('ValueSubject', () {
    test('emits items to every subscriber', () async {
      final subject = ValueSubject<int>();

      scheduleMicrotask(() {
        subject.add(1);
        subject.add(2);
        subject.add(3);
        subject.close();
      });

      await expectLater(
          subject.stream, emitsInOrder(<dynamic>[1, 2, 3, emitsDone]));
    });

    test(
        'emits items to every subscriber that subscribe directly to the Subject',
        () async {
      final subject = ValueSubject<int>();

      scheduleMicrotask(() {
        subject.add(1);
        subject.add(2);
        subject.add(3);
        subject.close();
      });

      await expectLater(subject, emitsInOrder(<dynamic>[1, 2, 3, emitsDone]));
    });

    test('emits done event to listeners when the subject is closed', () async {
      final subject = ValueSubject<int>();

      await expectLater(subject.isClosed, isFalse);

      scheduleMicrotask(() => subject.add(1));
      scheduleMicrotask(() => subject.close());

      await expectLater(subject.stream, emitsInOrder(<dynamic>[1, emitsDone]));
      await expectLater(subject.isClosed, isTrue);
    });

    test(
        'emits done event to listeners when the subject is closed (listen directly on Subject)',
        () async {
      final subject = ValueSubject<int>();

      await expectLater(subject.isClosed, isFalse);

      scheduleMicrotask(() => subject.add(1));
      scheduleMicrotask(() => subject.close());

      await expectLater(subject, emitsInOrder(<dynamic>[1, emitsDone]));
      await expectLater(subject.isClosed, isTrue);
    });

    test('emits error events to subscribers', () async {
      final subject = ValueSubject<int>();

      scheduleMicrotask(() => subject.addError(Exception()));

      await expectLater(subject.stream, emitsError(isException));
    });

    test('emits error events to subscribers (listen directly on Subject)',
        () async {
      final subject = ValueSubject<int>();

      scheduleMicrotask(() => subject.addError(Exception()));

      await expectLater(subject, emitsError(isException));
    });

    test('emits the items from addStream', () async {
      final subject = ValueSubject<int>();

      scheduleMicrotask(
          () => subject.addStream(Stream.fromIterable(const [1, 2, 3])));

      await expectLater(subject.stream, emitsInOrder(const <int>[1, 2, 3]));
    });

    test('allows items to be added once addStream is complete', () async {
      final subject = ValueSubject<int>();

      await subject.addStream(Stream.fromIterable(const [1, 2]));
      scheduleMicrotask(() => subject.add(3));

      await expectLater(subject.stream, emits(3));
    });

    test('allows items to be added once addStream is completes with an error',
        () async {
      final subject = ValueSubject<int>();

      unawaited(subject
          .addStream(Stream<int>.error(Exception()), cancelOnError: true)
          .whenComplete(() => subject.add(1)));

      await expectLater(subject.stream,
          emitsInOrder(<StreamMatcher>[emitsError(isException), emits(1)]));
    });

    test('does not allow events to be added when addStream is active',
        () async {
      final subject = ValueSubject<int>();

      // Purposely don't wait for the future to complete, then try to add items
      // ignore: unawaited_futures
      subject.addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.add(1), throwsStateError);
    });

    test('does not allow errors to be added when addStream is active',
        () async {
      final subject = ValueSubject<int>();

      // Purposely don't wait for the future to complete, then try to add items
      // ignore: unawaited_futures
      subject.addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.addError(Error()), throwsStateError);
    });

    test('does not allow subject to be closed when addStream is active',
        () async {
      final subject = ValueSubject<int>();

      // Purposely don't wait for the future to complete, then try to add items
      // ignore: unawaited_futures
      subject.addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.close(), throwsStateError);
    });

    test(
        'does not allow addStream to add items when previous addStream is active',
        () async {
      final subject = ValueSubject<int>();

      // Purposely don't wait for the future to complete, then try to add items
      // ignore: unawaited_futures
      subject.addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.addStream(Stream.fromIterable(const [1])),
          throwsStateError);
    });

    test('returns onListen callback set in constructor', () async {
      final testOnListen = () {};

      final subject = ValueSubject<int>(onListen: testOnListen);

      await expectLater(subject.onListen, testOnListen);
    });

    test('sets onListen callback', () async {
      final testOnListen = () {};

      final subject = ValueSubject<int>();

      await expectLater(subject.onListen, isNull);

      subject.onListen = testOnListen;

      await expectLater(subject.onListen, testOnListen);
    });

    test('returns onCancel callback set in constructor', () async {
      final onCancel = () => Future<Null>.value(null);

      final subject = ValueSubject<int>(onCancel: onCancel);

      await expectLater(subject.onCancel, onCancel);
    });

    test('sets onCancel callback', () async {
      final testOnCancel = () {};

      final subject = ValueSubject<int>();

      await expectLater(subject.onCancel, isNull);

      subject.onCancel = testOnCancel;

      await expectLater(subject.onCancel, testOnCancel);
    });

    test('reports if a listener is present', () async {
      final subject = ValueSubject<int>();

      await expectLater(subject.hasListener, isFalse);

      subject.stream.listen(null);

      await expectLater(subject.hasListener, isTrue);
    });

    test('onPause unsupported', () {
      final subject = ValueSubject<int>();

      expect(subject.isPaused, isFalse);
      expect(() => subject.onPause, throwsUnsupportedError);
      expect(() => subject.onPause = () {}, throwsUnsupportedError);
    });

    test('onResume unsupported', () {
      final subject = ValueSubject<int>();

      expect(() => subject.onResume, throwsUnsupportedError);
      expect(() => subject.onResume = () {}, throwsUnsupportedError);
    });

    test('returns controller sink', () async {
      final subject = ValueSubject<int>();

      await expectLater(subject.sink, TypeMatcher<EventSink<int>>());
    });

    test('correctly closes done Future', () async {
      final subject = ValueSubject<int>();

      scheduleMicrotask(() => subject.close());

      await expectLater(subject.done, completes);
    });

    test('can be listened to multiple times', () async {
      final subject = ValueSubject<int>();
      final stream = subject.stream;

      scheduleMicrotask(() => subject.add(1));
      await expectLater(stream, emits(1));

      scheduleMicrotask(() => subject.add(2));
      await expectLater(stream, emits(2));
    });

    test('always returns the same stream', () async {
      final subject = ValueSubject<int>();

      await expectLater(subject.stream, equals(subject.stream));
    });

    test('adding to sink has same behavior as adding to Subject itself',
        () async {
      final subject = ValueSubject<int>();

      scheduleMicrotask(() {
        subject.sink.add(1);
        subject.sink.add(2);
        subject.sink.add(3);
        subject.sink.close();
      });

      await expectLater(
          subject.stream, emitsInOrder(<dynamic>[1, 2, 3, emitsDone]));
    });

    test('is always treated as a broadcast Stream', () async {
      final subject = ValueSubject<int>();
      final stream = subject.asyncMap((event) => Future.value(event));

      expect(subject.isBroadcast, isTrue);
      expect(stream.isBroadcast, isTrue);
    });

    test('can synchronously get the latest value', () async {
      final unseeded = ValueSubject<int>(),
          seeded = ValueSubject<int>.seeded(0);

      unseeded.add(1);
      unseeded.add(2);
      unseeded.add(3);

      seeded.add(1);
      seeded.add(2);
      seeded.add(3);

      await expectLater(unseeded.value, 3);

      await expectLater(seeded.value, 3);
    });

    test('can synchronously get the latest null value', () async {
      final unseeded = ValueSubject<int>(),
          seeded = ValueSubject<int>.seeded(0);

      unseeded.add(1);
      unseeded.add(2);
      unseeded.add(null);

      seeded.add(1);
      seeded.add(2);
      seeded.add(null);

      await expectLater(unseeded.value, isNull);

      await expectLater(seeded.value, isNull);
    });

    test('can synchronously get the initial value', () {
      final subject = ValueSubject<int>.seeded(1);

      expect(subject.value, 1);
    });

    test('can synchronously get the initial null value', () {
      final subject = ValueSubject<int>.seeded(null);

      expect(subject.value, null);
    });

    test('initial value is null when no value has been emitted', () {
      final subject = ValueSubject<int>();

      expect(subject.value, isNull);
    });

    test('hasValue returns false for an empty subject', () {
      final subject = ValueSubject<int>();

      expect(subject.hasValue, isFalse);
    });

    test('hasValue returns true for a seeded subject with non-null seed', () {
      final subject = ValueSubject<int>.seeded(1);

      expect(subject.hasValue, isTrue);
    });

    test('hasValue returns true for a seeded subject with null seed', () {
      final subject = ValueSubject<int>.seeded(null);

      expect(subject.hasValue, isTrue);
    });

    test('hasValue returns true for an unseeded subject after an emission', () {
      final subject = ValueSubject<int>();

      subject.add(1);

      expect(subject.hasValue, isTrue);
    });
  });
}
