import 'dart:async';

import 'package:rxdart/src/utils/forwarding_sink.dart';
import 'package:rxdart/subjects.dart';

/// Helper method which forwards the events from an incoming [Stream]
/// to a new [StreamController].
/// It captures events such as onListen, onPause, onResume and onCancel,
/// which can be used in pair with a [ForwardingSink]
Stream<R> forwardStream<T, R>(
  Stream<T> stream,
  ForwardingSink<T, R> forwardingSink,
) {
  ArgumentError.checkNotNull(stream, 'stream');
  ArgumentError.checkNotNull(forwardingSink, 'sink');

  StreamController<R> controller;
  StreamSubscription<T> subscription;

  void _addError(Object error, StackTrace stackTrace) {
    if (controller.isClosed) {
      Zone.current.handleUncaughtError(error, stackTrace);
    } else {
      controller.addError(error, stackTrace);
    }
  }

  final onListen = () {
    try {
      forwardingSink.onListen(controller);
    } catch (e, s) {
      _addError(e, s);
    }

    subscription = stream.listen(
      (data) {
        try {
          forwardingSink.add(controller, data);
        } catch (e, s) {
          _addError(e, s);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        try {
          forwardingSink.addError(controller, error, stackTrace);
        } catch (e, s) {
          if (identical(e, error)) {
            _addError(error, stackTrace);
          } else {
            _addError(e, s);
          }
        }
      },
      onDone: () {
        try {
          forwardingSink.close(controller);
        } catch (e, s) {
          _addError(e, s);
        }
      },
    );
  };

  final onCancel = () {
    final cancelSubscriptionFuture = subscription.cancel();
    final cancelSinkFuture = forwardingSink.onCancel(controller);

    return cancelSinkFuture is Future<void>
        ? Future.wait([cancelSubscriptionFuture, cancelSinkFuture])
        : cancelSubscriptionFuture;
  };

  final onPause = () {
    try {
      forwardingSink.onPause(controller);
    } catch (e, s) {
      _addError(e, s);
    }
    subscription.pause();
  };

  final onResume = () {
    subscription.resume();
    try {
      forwardingSink.onResume(controller);
    } catch (e, s) {
      _addError(e, s);
    }
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
