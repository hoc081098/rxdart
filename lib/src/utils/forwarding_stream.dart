import 'dart:async';

import 'package:rxdart/src/utils/forwarding_sink.dart';
import 'package:rxdart/subjects.dart';

/// Helper method which forwards the events from an incoming [Stream]
/// to a new [StreamController].
/// It captures events such as onListen, onPause, onResume and onCancel,
/// which can be used in pair with a [ForwardingSink]
Stream<R> forwardStream<T, R>(
  Stream<T> stream,
  ForwardingSink<T, R> sink,
) {
  ArgumentError.checkNotNull(stream, 'stream');
  ArgumentError.checkNotNull(sink, 'sink');

  StreamController<R> controller;
  StreamSubscription<T> subscription;

  final onListen = () {
    sink.onListen(controller);

    subscription = stream.listen(
      (data) => sink.add(controller, data),
      onError: (Object e, StackTrace st) => sink.addError(controller, e, st),
      onDone: () => sink.close(controller),
    );
  };

  final onCancel = () {
    final cancelSubscriptionFuture = subscription.cancel();
    final cancelSinkFuture = sink.onCancel(controller);

    return cancelSinkFuture is Future<void>
        ? Future.wait([cancelSubscriptionFuture, cancelSinkFuture])
        : cancelSubscriptionFuture;
  };

  final onPause = () {
    subscription.pause();
    sink.onPause(controller);
  };

  final onResume = () {
    subscription.resume();
    sink.onResume(controller);
  };

  // Create a new Controller, which will serve as a trampoline for
  // forwarded events.
  if (stream is Subject<T>) {
    controller = stream.createForwardingSubject<R>(
      onListen: onListen,
      onCancel: onCancel,
      sync: true,
    );
  } else if (stream.isBroadcast) {
    controller = StreamController<R>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
      sync: true,
    );
  } else {
    controller = StreamController<R>(
      onListen: onListen,
      onPause: onPause,
      onResume: onResume,
      onCancel: onCancel,
      sync: true,
    );
  }

  return controller.stream;
}
