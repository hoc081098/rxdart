import 'dart:async';

import 'package:rxdart/src/utils/forwarding_sink.dart';
import 'package:rxdart/src/utils/forwarding_stream.dart';

class _DefaultIfEmptyStreamSink<S>
    with ForwardingSinkMixin<S, S>
    implements ForwardingSink<S, S> {
  final S _defaultValue;
  bool _isEmpty = true;

  _DefaultIfEmptyStreamSink(this._defaultValue);

  @override
  void add(EventSink<S> sink, S data) {
    _isEmpty = false;
    sink.add(data);
  }

  @override
  void close(EventSink<S> sink) {
    if (_isEmpty) {
      sink.add(_defaultValue);
    }

    sink.close();
  }
}

/// Emit items from the source [Stream], or a single default item if the source
/// Stream emits nothing.
///
/// ### Example
///
///     Stream.empty()
///       .transform(DefaultIfEmptyStreamTransformer(10))
///       .listen(print); // prints 10
class DefaultIfEmptyStreamTransformer<S> extends StreamTransformerBase<S, S> {
  /// The event that should be emitted if the source [Stream] is empty
  final S defaultValue;

  /// Constructs a [StreamTransformer] which either emits from the source [Stream],
  /// or just a [defaultValue] if the source [Stream] emits nothing.
  DefaultIfEmptyStreamTransformer(this.defaultValue);

  @override
  Stream<S> bind(Stream<S> stream) =>
      forwardStream(stream, _DefaultIfEmptyStreamSink<S>(defaultValue));
}

///
extension DefaultIfEmptyExtension<T> on Stream<T> {
  /// Emit items from the source Stream, or a single default item if the source
  /// Stream emits nothing.
  ///
  /// ### Example
  ///
  ///     Stream.empty().defaultIfEmpty(10).listen(print); // prints 10
  Stream<T> defaultIfEmpty(T defaultValue) =>
      transform(DefaultIfEmptyStreamTransformer<T>(defaultValue));
}
