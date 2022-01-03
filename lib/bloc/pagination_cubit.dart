import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

part 'pagination_state.dart';

enum PaginationDirection { previous, next }

class PaginationCubit extends Cubit<PaginationState> {
  PaginationCubit(
    this._query,
    this._limit,
    this._startAfterDocument,
    this._startAtDocument,
    this._startAt, {
    this.isLive = false,
    this.includeMetadataChanges = false,
    this.options,
  }) : super(PaginationInitial());

  DocumentSnapshot? _lastDocument;
  DocumentSnapshot? _firstDocument;
  final int _limit;
  final Query _query;
  final DocumentSnapshot? _startAfterDocument;
  final DocumentSnapshot? _startAtDocument;
  final List<Object>? _startAt;
  final bool isLive;
  final bool includeMetadataChanges;
  final GetOptions? options;

  final _streams = <StreamSubscription<QuerySnapshot>>[];

  List<QueryDocumentSnapshot> _filterBySearchTerm(
          List<QueryDocumentSnapshot> items, String searchTerm) =>
      items
          .where((document) => document
              .data()
              .toString()
              .toLowerCase()
              .contains(searchTerm.toLowerCase()))
          .toList();

  void filterPaginatedList(String searchTerm) {
    if (state is PaginationLoaded) {
      final loadedState = state as PaginationLoaded;

      final filteredTop = _filterBySearchTerm(loadedState.top, searchTerm);
      final filteredBottom =
          _filterBySearchTerm(loadedState.bottom, searchTerm);

      emit(loadedState.copyWith(
        top: filteredTop,
        bottom: filteredBottom,
        hasReachedBeginning: loadedState.hasReachedBeginning,
        hasReachedEnd: loadedState.hasReachedEnd,
      ));
    }
  }

  void refreshPaginatedList({required PaginationDirection direction}) async {
    if (direction == PaginationDirection.next) {
      _lastDocument = null;
    } else {
      _firstDocument = null;
    }
    final localQuery = _getQuery(direction: direction);
    if (isLive) {
      final listener = localQuery
          ?.snapshots(includeMetadataChanges: includeMetadataChanges)
          .listen((querySnapshot) {
        _emitPaginatedState(querySnapshot.docs, direction: direction);
      });

      if (listener != null) {
        _streams.add(listener);
      }
    } else {
      final querySnapshot = await localQuery?.get(options);
      if (querySnapshot != null) {
        _emitPaginatedState(querySnapshot.docs, direction: direction);
      }
    }
  }

  void fetchPaginatedList(
      {PaginationDirection direction = PaginationDirection.next}) {
    isLive
        ? _getLiveDocuments(direction: direction)
        : _getDocuments(direction: direction);
  }

  bool _hasReachedEndOrBeginning(
          PaginationLoaded state, PaginationDirection direction) =>
      state.hasReachedEnd && direction == PaginationDirection.next ||
      state.hasReachedBeginning && direction == PaginationDirection.previous;

  _getDocuments({required PaginationDirection direction}) async {
    final localQuery = _getQuery(direction: direction);
    try {
      if (state is PaginationInitial) {
        refreshPaginatedList(direction: direction);
      } else if (state is PaginationLoaded) {
        final loadedState = state as PaginationLoaded;
        if (_hasReachedEndOrBeginning(loadedState, direction)) return;
        final querySnapshot = await localQuery?.get(options);
        if (querySnapshot != null) {
          _emitPaginatedState(
            querySnapshot.docs,
            direction: direction,
            previousList: direction == PaginationDirection.next
                ? loadedState.bottom
                : loadedState.top,
          );
        }
      }
    } on PlatformException catch (exception) {
      // ignore: avoid_print
      print(exception);
      rethrow;
    }
  }

  _getLiveDocuments({required PaginationDirection direction}) {
    final localQuery = _getQuery(direction: direction);
    if (state is PaginationInitial) {
      refreshPaginatedList(direction: direction);
    } else if (state is PaginationLoaded) {
      final loadedState = state as PaginationLoaded;
      if (_hasReachedEndOrBeginning(loadedState, direction)) return;
      final listener = localQuery
          ?.snapshots(includeMetadataChanges: includeMetadataChanges)
          .listen((querySnapshot) {
        _emitPaginatedState(
          querySnapshot.docs,
          direction: direction,
          previousList: direction == PaginationDirection.next
              ? loadedState.bottom
              : loadedState.top,
        );
      });

      if (listener != null) {
        _streams.add(listener);
      }
    }
  }

  void _emitPaginatedState(
    List<QueryDocumentSnapshot> newList, {
    required PaginationDirection direction,
    List<QueryDocumentSnapshot> previousList = const [],
  }) {
    if (direction == PaginationDirection.next) {
      _lastDocument = newList.isNotEmpty ? newList.last : null;
      emit(PaginationLoaded(
        bottom: _mergeSnapshots(previousList, newList, direction: direction),
        top: (state is PaginationLoaded) ? (state as PaginationLoaded).top : [],
        hasReachedEnd: newList.isEmpty,
        hasReachedBeginning: (state is PaginationLoaded)
            ? (state as PaginationLoaded).hasReachedBeginning
            : false,
      ));
    } else {
      _firstDocument = newList.isNotEmpty ? newList.first : null;
      emit(PaginationLoaded(
        top: _mergeSnapshots(previousList, newList, direction: direction),
        bottom: (state is PaginationLoaded)
            ? (state as PaginationLoaded).bottom
            : [],
        hasReachedEnd: (state is PaginationLoaded)
            ? (state as PaginationLoaded).hasReachedEnd
            : false,
        hasReachedBeginning: newList.isEmpty,
      ));
    }
  }

  List<QueryDocumentSnapshot> _mergeSnapshots(
    List<QueryDocumentSnapshot> previousList,
    List<QueryDocumentSnapshot> newList, {
    required PaginationDirection direction,
  }) {
    final prevIds = previousList.map((prevSnapshot) => prevSnapshot.id).toSet();
    newList.retainWhere((newSnapshot) => prevIds.add(newSnapshot.id));
    if (newList.isEmpty) return previousList;
    if (direction == PaginationDirection.next) {
      return [...previousList, ...newList];
    } else {
      return [...newList, ...previousList];
    }
  }

  Query? _getQuery({required PaginationDirection direction}) {
    Query? localQuery;
    if (direction == PaginationDirection.next) {
      localQuery = (_lastDocument != null)
          ? _query.startAfterDocument(_lastDocument!)
          : _startAt != null
              ? _query.startAt(_startAt!)
              : _startAtDocument != null
                  ? _query.startAtDocument(_startAtDocument!)
                  : _startAfterDocument != null
                      ? _query.startAfterDocument(_startAfterDocument!)
                      : _query;
    } else {
      localQuery = (_firstDocument != null)
          ? _query.endBeforeDocument(_firstDocument!)
          : _startAt != null
              ? _query.endBefore(_startAt!)
              : _startAtDocument != null
                  ? _query.endBeforeDocument(_startAtDocument!)
                  : _startAfterDocument != null
                      ? _query.endAtDocument(_startAfterDocument!)
                      : null;
    }
    localQuery = localQuery?.limit(_limit);
    return localQuery;
  }

  void dispose() {
    for (var listener in _streams) {
      listener.cancel();
    }
  }
}
