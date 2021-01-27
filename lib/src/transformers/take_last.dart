import 'dart:async';
import 'dart:collection';

import 'package:rxdart/src/utils/forwarding_sink.dart';
import 'package:rxdart/src/utils/forwarding_stream.dart';
import 'package:rxdart/src/utils/queue.dart';

class _TakeLastStreamSink<T> implements ForwardingSink<T, T> {
  final int count;
  final Queue<T> queue = DoubleLinkedQueue<T>();
  StreamSubscription<T> subscription;

  _TakeLastStreamSink(this.count);

  @override
  void add(EventSink<T> sink, T data) {
    queue.add(data);
    if (queue.length > count) {
      queue.removeFirstElements(queue.length - count);
    }
  }

  @override
  void addError(EventSink<T> sink, Object error, [StackTrace st]) =>
      sink.addError(error, st);

  @override
  void close(EventSink<T> sink) {
    if (queue.isEmpty) {
      sink.close();
      return;
    }

    subscription = Stream.fromIterable(queue).listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
  }

  @override
  FutureOr<void> onCancel(EventSink<T> sink) => subscription?.cancel();

  @override
  void onListen(EventSink<T> sink) {}

  @override
  void onPause(EventSink<T> sink) => subscription?.pause();

  @override
  void onResume(EventSink<T> sink) => subscription?.resume();
}

class TakeLastStreamTransformer<T> extends StreamTransformerBase<T, T> {
  final int count;

  TakeLastStreamTransformer(this.count) : assert(count != null && count >= 0);

  @override
  Stream<T> bind(Stream<T> stream) =>
      forwardStream(stream, _TakeLastStreamSink(count));
}

extension TakeLastExtension<T> on Stream<T> {
  Stream<T> takeLast(int count) => transform(TakeLastStreamTransformer(count));
}
