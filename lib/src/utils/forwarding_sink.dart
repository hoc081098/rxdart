import 'dart:async';

/// A [Sink] that supports event hooks.
///
/// This makes it suitable for certain rx transformers that need to
/// take action after onListen, onPause, onResume or onCancel.
///
/// The [ForwardingSink] has been designed to handle asynchronous events from
/// [Stream]s. See, for example, [Stream.eventTransformed] which uses
/// `EventSink`s to transform events.
abstract class ForwardingSink<T, R> {
  ForwardingEventSink<R>? _sink;

  ForwardingEventSink<R> get sink =>
      _sink ?? (throw StateError('Must call setSink(sink) before accessing!'));

  void setSink(ForwardingEventSink<R> sink) => _sink = sink;

  /// Handle data event
  void onData(T data);

  /// Handle error event
  void onError(Object error, StackTrace st);

  /// Handle close event
  void onDone();

  /// Fires when a listener subscribes on the underlying [Stream].
  /// Returns a [Future] to delay listening to source [Stream].
  FutureOr<void> onListen();

  /// Fires when a subscriber pauses.
  void onPause();

  /// Fires when a subscriber resumes after a pause.
  void onResume();

  /// Fires when a subscriber cancels.
  FutureOr<void> onCancel();
}

class ForwardingEventSink<T> {
  final EventSink<T> sinkAllStreams;
  final EventSink<T> sinkPerStream;

  ForwardingEventSink(this.sinkAllStreams, this.sinkPerStream);
}
