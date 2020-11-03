import 'dart:async';

/// Forward all [Stream] event to [EventSink].
extension StreamPipeToSink<T> on Stream<T> {
  /// Forward all [Stream] event to [sink].
  StreamSubscription<T> pipeTo(EventSink<T> sink) => listen(
        sink.add,
        onError: sink.addError,
        onDone: sink.close,
      );
}
