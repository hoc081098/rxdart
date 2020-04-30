import 'dart:async';

import 'package:rxdart/src/streams/value_stream.dart';
import 'package:rxdart/src/subjects/subject.dart';

/// A special StreamController that captures the latest item that has been
/// added to the controller.
///
/// ValueSubject is the same as PublishSubject, with the ability to capture
/// latest item that has been added to the controller.
///
/// ValueSubject is, by default, a broadcast (aka hot) controller, in order
/// to fulfill the Rx Subject contract. This means the Subject's `stream` can
/// be listened to multiple times.
///
/// ### Example
///
///     final subject = ValueSubject<int>();
///
///     subject.add(1);
///     subject.add(2);
///
///     print(subject.value);          // prints 2
///
///     // observers will receive 3 and done events.
///     subject.stream.listen(print); // prints 3
///     subject.stream.listen(print); // prints 3
///     subject.stream.listen(print); // prints 3
///
///     subject.add(3);
///     subject.close();
///
/// ### Example with seed value
///
///     final subject = ValueSubject<int>.seeded(1);
///
///     print(subject.value);          // prints 1
///
///     // observers will receive 3 and done events.
///     subject.stream.listen(print); // prints 2
///     subject.stream.listen(print); // prints 2
///     subject.stream.listen(print); // prints 2
///
///     subject.add(2);
///     subject.close();
///
class ValueSubject<T> extends Subject<T> implements ValueStream<T> {
  _Wrapper<T> _wrapper;

  ValueSubject._(
    StreamController<T> controller,
    Stream<T> stream,
    this._wrapper,
  ) : super(controller, stream);

  /// Constructs a [ValueSubject], optionally pass handlers for
  /// [onListen], [onCancel] and a flag to handle events [sync].
  ///
  /// See also [StreamController.broadcast]
  factory ValueSubject({
    void Function() onListen,
    void Function() onCancel,
    bool sync = false,
  }) {
    // ignore: close_sinks
    final controller = StreamController<T>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
      sync: sync,
    );

    final wrapper = _Wrapper<T>();

    return ValueSubject<T>._(controller, controller.stream, wrapper);
  }

  /// Constructs a [ValueSubject], optionally pass handlers for
  /// [onListen], [onCancel] and a flag to handle events [sync].
  ///
  /// [seedValue] becomes the current [value] and is emitted immediately.
  ///
  /// See also [StreamController.broadcast]
  factory ValueSubject.seeded(
    T seedValue, {
    void Function() onListen,
    void Function() onCancel,
    bool sync = false,
  }) {
    // ignore: close_sinks
    final controller = StreamController<T>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
      sync: sync,
    );

    final wrapper = _Wrapper<T>.seeded(seedValue);

    return ValueSubject<T>._(
      controller,
      controller.stream,
      wrapper,
    );
  }

  @override
  void onAdd(T event) => _wrapper.setValue(event);

  @override
  void onAddError(Object error, [StackTrace stackTrace]) =>
      _wrapper.setError(error, stackTrace);

  @override
  ValueStream<T> get stream => this;

  @override
  bool get hasValue => _wrapper.latestIsValue;

  @override
  T get value => _wrapper.latestValue;

  /// Set and emit the new value
  set value(T newValue) => add(newValue);

  @override
  StreamController<R> createForwardingController<R>({
    void Function() onListen,
    void Function() onCancel,
    bool sync = false,
  }) =>
      ValueSubject(onCancel: onCancel, onListen: onListen, sync: sync);
}

class _Wrapper<T> {
  T latestValue;
  Object latestError;
  StackTrace latestStackTrace;

  bool latestIsValue = false, latestIsError = false;

  /// Non-seeded constructor
  _Wrapper();

  _Wrapper.seeded(this.latestValue) : latestIsValue = true;

  void setValue(T event) {
    latestIsValue = true;
    latestIsError = false;

    latestValue = event;

    latestError = null;
    latestStackTrace = null;
  }

  void setError(Object error, [StackTrace stackTrace]) {
    latestIsValue = false;
    latestIsError = true;

    latestValue = null;

    latestError = error;
    latestStackTrace = stackTrace;
  }
}
