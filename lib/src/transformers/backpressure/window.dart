import 'dart:async';

import 'package:rxdart/src/transformers/backpressure/backpressure.dart';
import 'package:rxdart/src/utils/forwarding_sink.dart';
import 'package:rxdart/src/utils/forwarding_stream.dart';

/// Creates a [Stream] where each item is a [Stream] containing the items
/// from the source sequence.
///
/// This [List] is emitted every time the window [Stream]
/// emits an event.
///
/// ### Example
///
///     Stream.periodic(const Duration(milliseconds: 100), (i) => i)
///       .window(Stream.periodic(const Duration(milliseconds: 160), (i) => i))
///       .asyncMap((stream) => stream.toList())
///       .listen(print); // prints [0, 1] [2, 3] [4, 5] ...
class WindowStreamTransformer<T>
    extends BackpressureStreamTransformer<T, Stream<T>> {
  /// Constructs a [StreamTransformer] which buffers events into a [Stream] and
  /// emits this [Stream] whenever [window] fires an event.
  ///
  /// The [Stream] is recreated and starts empty upon every [window] event.
  WindowStreamTransformer(Stream Function(T event) window)
      : super(WindowStrategy.firstEventOnly, window,
            onWindowEnd: (List<T> queue) => Stream.fromIterable(queue),
            ignoreEmptyWindows: false) {
    if (window == null) throw ArgumentError.notNull('window');
  }
}

/// Buffers a number of values from the source Stream by count then emits the
/// buffer as a [Stream] and clears it, and starts a new buffer each
/// startBufferEvery values. If startBufferEvery is not provided, then new
/// buffers are started immediately at the start of the source and when each
/// buffer closes and is emitted.
///
/// ### Example
/// count is the maximum size of the buffer emitted
///
///     Rx.range(1, 4)
///       .windowCount(2)
///       .asyncMap((stream) => stream.toList())
///       .listen(print); // prints [1, 2], [3, 4] done!
///
/// ### Example
/// if startBufferEvery is 2, then a new buffer will be started
/// on every other value from the source. A new buffer is started at the
/// beginning of the source by default.
///
///     Rx.range(1, 5)
///       .bufferCount(3, 2)
///       .listen(print); // prints [1, 2, 3], [3, 4, 5], [5] done!
class WindowCountStreamTransformer<T>
    extends BackpressureStreamTransformer<T, Stream<T>> {
  /// Constructs a [StreamTransformer] which buffers events into a [Stream] and
  /// emits this [Stream] whenever its length is equal to [count].
  ///
  /// A new buffer is created for every n-th event emitted
  /// by the [Stream] that is being transformed, as specified by
  /// the [startBufferEvery] parameter.
  ///
  /// If [startBufferEvery] is omitted or equals 0, then a new buffer is started whenever
  /// the previous one reaches a length of [count].
  WindowCountStreamTransformer(int count, [int startBufferEvery = 0])
      : super(WindowStrategy.onHandler, null,
            onWindowEnd: (List<T> queue) => Stream.fromIterable(queue),
            startBufferEvery: startBufferEvery,
            closeWindowWhen: (Iterable<T> queue) => queue.length == count) {
    if (count == null) throw ArgumentError.notNull('count');
    if (startBufferEvery == null) {
      throw ArgumentError.notNull('startBufferEvery');
    }
    if (count < 1) throw ArgumentError.value(count, 'count');
    if (startBufferEvery < 0) {
      throw ArgumentError.value(startBufferEvery, 'startBufferEvery');
    }
  }
}

/// Creates a [Stream] where each item is a [Stream] containing the items
/// from the source sequence, batched whenever test passes.
///
/// ### Example
///
///     Stream.periodic(const Duration(milliseconds: 100), (int i) => i)
///       .windowTest((i) => i % 2 == 0)
///       .asyncMap((stream) => stream.toList())
///       .listen(print); // prints [0], [1, 2] [3, 4] [5, 6] ...
class WindowTestStreamTransformer<T>
    extends BackpressureStreamTransformer<T, Stream<T>> {
  /// Constructs a [StreamTransformer] which buffers events into a [Stream] and
  /// emits this [Stream] whenever the [test] Function yields true.
  WindowTestStreamTransformer(bool Function(T value) test)
      : super(WindowStrategy.onHandler, null,
            onWindowEnd: (List<T> queue) => Stream.fromIterable(queue),
            closeWindowWhen: (Iterable<T> queue) => test(queue.last)) {
    if (test == null) throw ArgumentError.notNull('test');
  }
}

class _WindowWhenStreamSink<T> implements ForwardingSink<T, Stream<T>> {
  final Stream<void> Function() _closingSelector;

  StreamSubscription<void> _closingSubscription;
  var _window = StreamController<T>();
  var _closed = false;

  _WindowWhenStreamSink(this._closingSelector);

  @override
  void add(EventSink<Stream<T>> sink, T data) => _window.add(data);

  @override
  void addError(EventSink<Stream<T>> sink, Object error, [StackTrace st]) {
    _window.addError(error, st);
    sink.addError(error, st);
  }

  @override
  void close(EventSink<Stream<T>> sink) {
    _window.close();
    sink.close();
    _closed = true;
  }

  @override
  FutureOr onCancel(EventSink<Stream<T>> sink) =>
      _closingSubscription?.cancel();

  @override
  void onListen(EventSink<Stream<T>> sink) => scheduleMicrotask(() {
        if (!_closed) {
          _openWindow(sink, false);
        }
      });

  @override
  void onPause(EventSink<Stream<T>> sink, [Future<dynamic> resumeSignal]) =>
      _closingSubscription?.resume();

  @override
  void onResume(EventSink<Stream<T>> sink) => _closingSubscription?.resume();

  void _openWindow(EventSink<Stream<T>> sink, [bool createNewWindow = true]) {
    _closingSubscription?.cancel();

    if (createNewWindow) {
      _window.close();
      _window = StreamController<T>();
    }
    sink.add(_window.stream);

    Stream<void> stream;
    try {
      stream = _closingSelector();
    } catch (e, st) {
      _window.addError(e, st);
      sink.addError(e, st);
      return;
    }

    _closingSubscription = stream.take(1).listen(
          null,
          onError: (Object e, StackTrace st) {
            _window.addError(e, st);
            sink.addError(e, st);
          },
          onDone: () => _openWindow(sink),
        );
  }
}

///
class WindowWhenStreamTransformer<T>
    extends StreamTransformerBase<T, Stream<T>> {
  final Stream<void> Function() _closingSelector;

  ///
  WindowWhenStreamTransformer(this._closingSelector)
      : assert(_closingSelector != null);

  @override
  Stream<Stream<T>> bind(Stream<T> stream) =>
      forwardStream(stream, _WindowWhenStreamSink(_closingSelector));
}

class _ToggleWindow<T> {
  final StreamController<T> controller;
  final StreamSubscription<void> subscription;

  _ToggleWindow(this.controller, this.subscription);
}

class _WindowToggleSink<T, R> implements ForwardingSink<T, Stream<T>> {
  final Stream<R> _openings;
  final Stream<void> Function(R) _closingSelector;

  final _windows = <_ToggleWindow<T>>[];
  StreamSubscription<R> _openingsSubscription;

  _WindowToggleSink(this._openings, this._closingSelector);

  @override
  void add(EventSink<Stream<T>> sink, T data) =>
      _windows.forEach((w) => w.controller.add(data));

  @override
  void addError(EventSink<Stream<T>> sink, Object error, [StackTrace st]) {
    _windows.forEach((w) => w.controller.addError(error, st));
    sink.addError(error, st);
  }

  @override
  void close(EventSink<Stream<T>> sink) {
    _windows.forEach((w) => w.controller.close());
    sink.close();
  }

  @override
  FutureOr onCancel(EventSink<Stream<T>> sink) {
    var future = _openingsSubscription?.cancel();
    final futures = [
      for (final future in _windows.map((w) => w.subscription?.cancel()))
        if (future != null) future,
      if (future != null) future,
    ];

    if (futures.isNotEmpty) {
      return Future.wait(futures);
    }
  }

  @override
  void onListen(EventSink<Stream<T>> sink) {
    _openingsSubscription = _openings.listen(
      (event) => _open(event, sink),
      onError: (Object error, StackTrace st) => addError(sink, error, st),
      // ignore done event
    );
  }

  @override
  void onPause(EventSink<Stream<T>> sink, [Future<dynamic> resumeSignal]) {
    _windows.forEach((w) => w.subscription.pause());
  }

  @override
  void onResume(EventSink<Stream<T>> sink) =>
      _windows.forEach((w) => w.subscription.resume());

  void _open(R event, EventSink<Stream<T>> sink) {
    Stream<void> closingNotifier;
    try {
      closingNotifier = _closingSelector(event);
    } catch (e, st) {
      sink.addError(e, st);
      return;
    }

    // Construct a window for this opening event.
    _ToggleWindow<T> window;
    final controller = StreamController<T>();
    final subscription = closingNotifier.take(1).listen(
          null,
          onError: (Object e, StackTrace st) {},
          onDone: () => _close(window),
        );
    window = _ToggleWindow(controller, subscription);

    _windows.add(window);
    sink.add(controller.stream);
  }

  void _close(_ToggleWindow<T> window) {
    if (window == null) {
      return;
    }

    window.controller.close();
    window.subscription?.cancel();

    _windows.remove(window);
  }
}

///
class WindowToggleStreamTransformer<T, R>
    extends StreamTransformerBase<T, Stream<T>> {
  final Stream<R> _openings;
  final Stream<void> Function(R) _closingSelector;

  ///
  WindowToggleStreamTransformer(this._openings, this._closingSelector);

  @override
  Stream<Stream<T>> bind(Stream<T> stream) =>
      forwardStream(stream, _WindowToggleSink(_openings, _closingSelector));
}

/// Extends the Stream class with the ability to window
extension WindowExtensions<T> on Stream<T> {
  /// Creates a Stream where each item is a [Stream] containing the items from
  /// the source sequence.
  ///
  /// This [List] is emitted every time [window] emits an event.
  ///
  /// ### Example
  ///
  ///     Stream.periodic(Duration(milliseconds: 100), (i) => i)
  ///       .window(Stream.periodic(Duration(milliseconds: 160), (i) => i))
  ///       .asyncMap((stream) => stream.toList())
  ///       .listen(print); // prints [0, 1] [2, 3] [4, 5] ...
  Stream<Stream<T>> window(Stream window) =>
      transform(WindowStreamTransformer((_) => window));

  /// Creates a Stream where each item is a [Stream] containing the items from
  /// the source sequence.
  ///
  /// This [List] is emitted every time Stream from calls [closingNotifier] emits an event.
  ///
  /// ### Example
  ///
  ///     Stream.periodic(Duration(milliseconds: 100), (i) => i)
  ///         .windowWhen(() => Rx.timer(null, const Duration(milliseconds: 160)))
  ///         .flatMap((stream) => stream.toList().asStream())
  ///         .listen(print); // prints [0] [1, 2] [3] [4, 5] ...
  Stream<Stream<T>> windowWhen(Stream<void> Function() closingSelector) =>
      transform(WindowWhenStreamTransformer(closingSelector));

  ///
  /// ### Example
  ///
  ///     Stream.periodic(Duration(milliseconds: 100), (i) => i)
  ///       .windowToggle(
  ///         Stream.periodic(const Duration(milliseconds: 270), (i) => i + 1),
  ///         (int i) => Rx.timer(null, Duration(milliseconds: i * 130)),
  ///       )
  ///       .flatMap((stream) => stream.toList().asStream())
  ///       .listen(print); // prints [2, 3] [5, 6] [8, 9, 10] ...
  Stream<Stream<T>> windowToggle<R>(
          Stream<R> openings, Stream<void> Function(R) closingSelector) =>
      transform(WindowToggleStreamTransformer(openings, closingSelector));

  /// Buffers a number of values from the source Stream by [count] then emits
  /// the buffer as a [Stream] and clears it, and starts a new buffer each
  /// [startBufferEvery] values. If [startBufferEvery] is not provided, then new
  /// buffers are started immediately at the start of the source and when each
  /// buffer closes and is emitted.
  ///
  /// ### Example
  /// [count] is the maximum size of the buffer emitted
  ///
  ///     RangeStream(1, 4)
  ///       .windowCount(2)
  ///       .asyncMap((stream) => stream.toList())
  ///       .listen(print); // prints [1, 2], [3, 4] done!
  ///
  /// ### Example
  /// if [startBufferEvery] is 2, then a new buffer will be started
  /// on every other value from the source. A new buffer is started at the
  /// beginning of the source by default.
  ///
  ///     RangeStream(1, 5)
  ///       .bufferCount(3, 2)
  ///       .listen(print); // prints [1, 2, 3], [3, 4, 5], [5] done!
  Stream<Stream<T>> windowCount(int count, [int startBufferEvery = 0]) =>
      transform(WindowCountStreamTransformer(count, startBufferEvery));

  /// Creates a Stream where each item is a [Stream] containing the items from
  /// the source sequence, batched whenever test passes.
  ///
  /// ### Example
  ///
  ///     Stream.periodic(Duration(milliseconds: 100), (int i) => i)
  ///       .windowTest((i) => i % 2 == 0)
  ///       .asyncMap((stream) => stream.toList())
  ///       .listen(print); // prints [0], [1, 2] [3, 4] [5, 6] ...
  Stream<Stream<T>> windowTest(bool Function(T event) onTestHandler) =>
      transform(WindowTestStreamTransformer(onTestHandler));

  /// Creates a Stream where each item is a [Stream] containing the items from
  /// the source sequence, sampled on a time frame with [duration].
  ///
  /// ### Example
  ///
  ///     Stream.periodic(Duration(milliseconds: 100), (int i) => i)
  ///       .windowTime(Duration(milliseconds: 220))
  ///       .doOnData((_) => print('next window'))
  ///       .flatMap((s) => s)
  ///       .listen(print); // prints next window 0, 1, next window 2, 3, ...
  Stream<Stream<T>> windowTime(Duration duration) {
    if (duration == null) throw ArgumentError.notNull('duration');

    return window(Stream<void>.periodic(duration));
  }
}
