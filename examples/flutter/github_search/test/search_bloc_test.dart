import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_search/api/github_api.dart';
import 'package:github_search/bloc/search_bloc.dart';
import 'package:github_search/bloc/search_state.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';

import 'search_bloc_test.mocks.dart';

// To gen 'search_bloc_test.mocks.dart', run: flutter packages pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([GithubApi])
void main() {
  group('SearchBloc', () {
    test('starts with an initial no term state', () {
      final api = MockGithubApi();
      final bloc = SearchBloc(api);

      expect(
        bloc.state.startWith(bloc.state.value),
        emitsInOrder([noTerm]),
      );
    });

    test('emits a loading state then result state when api call succeeds', () {
      final api = MockGithubApi();
      final bloc = SearchBloc(api);

      when(api.search('T')).thenAnswer(
          (_) async => const SearchResult([SearchResultItem('A', 'B', 'C')]));

      scheduleMicrotask(() {
        bloc.onTextChanged.add('T');
      });

      expect(
        bloc.state.startWith(bloc.state.value),
        emitsInOrder([noTerm, loading, populated]),
      );
    });

    test('emits a no term state when user provides an empty search term', () {
      final api = MockGithubApi();
      final bloc = SearchBloc(api);

      scheduleMicrotask(() {
        bloc.onTextChanged.add('');
      });

      expect(
        bloc.state.startWith(bloc.state.value),
        emitsInOrder([noTerm]),
      );
    });

    test('emits an empty state when no results are returned', () {
      final api = MockGithubApi();
      final bloc = SearchBloc(api);

      when(api.search('T')).thenAnswer((_) async => const SearchResult([]));

      scheduleMicrotask(() {
        bloc.onTextChanged.add('T');
      });

      expect(
        bloc.state.startWith(bloc.state.value),
        emitsInOrder([noTerm, loading, empty]),
      );
    });

    test('throws an error when the backend errors', () {
      final api = MockGithubApi();
      final bloc = SearchBloc(api);

      when(api.search('T')).thenThrow(Exception());

      scheduleMicrotask(() {
        bloc.onTextChanged.add('T');
      });

      expect(
        bloc.state.startWith(bloc.state.value),
        emitsInOrder([noTerm, loading, error]),
      );
    });

    test('closes the stream on dispose', () {
      final api = MockGithubApi();
      final bloc = SearchBloc(api);

      scheduleMicrotask(() {
        bloc.dispose();
      });

      expect(
        bloc.state.startWith(bloc.state.value),
        emitsInOrder([noTerm, emitsDone]),
      );
    });
  });
}

final noTerm = isA<SearchNoTerm>();

final loading = isA<SearchLoading>();

final empty = isA<SearchEmpty>();

final populated = isA<SearchPopulated>();

final error = isA<SearchError>();
