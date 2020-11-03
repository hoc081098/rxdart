import 'dart:async';

import 'package:rxdart/src/utils/forwarding_sink.dart';
import 'package:rxdart/src/utils/forwarding_stream.dart';

class _ScanStreamSink<S, T>
    with ForwardingSinkMixin<S, T>
    implements ForwardingSink<S, T> {
  final T Function(T accumulated, S value, int index) _accumulator;
  T _acc;
  var _index = 0;

  _ScanStreamSink(this._accumulator, [T seed]) : _acc = seed;

  @override
  void add(EventSink<T> sink, S data) {
    _acc = _accumulator(_acc, data, _index++);

    sink.add(_acc);
  }
}

/// Applies an accumulator function over an stream sequence and returns
/// each intermediate result. The optional seed value is used as the initial
/// accumulator value.
///
/// ### Example
///
///     Stream.fromIterable([1, 2, 3])
///        .transform(ScanStreamTransformer((acc, curr, i) => acc + curr, 0))
///        .listen(print); // prints 1, 3, 6
class ScanStreamTransformer<S, T> extends StreamTransformerBase<S, T> {
  /// Method which accumulates incoming event into a single, accumulated object
  final T Function(T accumulated, S value, int index) accumulator;

  /// The initial value for the accumulated value in the [accumulator]
  final T seed;

  /// Constructs a [ScanStreamTransformer] which applies an accumulator Function
  /// over the source [Stream] and returns each intermediate result.
  /// The optional seed value is used as the initial accumulator value.
  ScanStreamTransformer(this.accumulator, [this.seed]);

  @override
  Stream<T> bind(Stream<S> stream) =>
      forwardStream(stream, _ScanStreamSink<S, T>(accumulator, seed));
}

/// Extends
extension ScanExtension<T> on Stream<T> {
  /// Applies an accumulator function over a Stream sequence and returns each
  /// intermediate result. The optional seed value is used as the initial
  /// accumulator value.
  ///
  /// ### Example
  ///
  ///     Stream.fromIterable([1, 2, 3])
  ///        .scan((acc, curr, i) => acc + curr, 0)
  ///        .listen(print); // prints 1, 3, 6
  Stream<S> scan<S>(
    S Function(S accumulated, T value, int index) accumulator, [
    S seed,
  ]) =>
      transform(ScanStreamTransformer<T, S>(accumulator, seed));
}
