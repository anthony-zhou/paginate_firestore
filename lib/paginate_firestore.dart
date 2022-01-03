library paginate_firestore;

// TODO: find where the current scroll position actually starts (i.e., how much extra space was added at the top) and jump to there
// TODO: hide the frame where we are jumping to the correct scroll position. (using a callback of some sort).

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'bloc/pagination_cubit.dart';
import 'bloc/pagination_listeners.dart';
import 'widgets/bottom_loader.dart';
import 'widgets/empty_display.dart';
import 'widgets/empty_separator.dart';
import 'widgets/error_display.dart';
import 'widgets/initial_loader.dart';

class PaginateFirestore extends StatefulWidget {
  const PaginateFirestore({
    Key? key,
    required this.itemBuilder,
    required this.query,
    required this.itemBuilderType,
    this.gridDelegate =
        const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
    this.startAfterDocument,
    this.startAtDocument,
    this.startAt,
    this.itemsPerPage = 15,
    this.onError,
    this.onReachedEnd,
    this.onLoaded,
    this.onEmpty = const EmptyDisplay(),
    this.separator = const EmptySeparator(),
    this.initialLoader = const InitialLoader(),
    this.bottomLoader = const BottomLoader(),
    this.shrinkWrap = false,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.padding = const EdgeInsets.all(0),
    this.physics,
    this.listeners,
    this.scrollController,
    this.allowImplicitScrolling = false,
    this.pageController,
    this.onPageChanged,
    this.header,
    this.footer,
    this.isLive = false,
    this.includeMetadataChanges = false,
    this.options,
  }) : super(key: key);

  final Widget bottomLoader;
  final Widget onEmpty;
  final SliverGridDelegate gridDelegate;
  final Widget initialLoader;
  final PaginateBuilderType itemBuilderType;
  final int itemsPerPage;
  final List<ChangeNotifier>? listeners;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final Query query;
  final bool reverse;
  final bool allowImplicitScrolling;
  final ScrollController? scrollController;
  final PageController? pageController;
  final Axis scrollDirection;
  final Widget separator;
  final bool shrinkWrap;
  final bool isLive;
  final DocumentSnapshot? startAfterDocument;
  // startAtDocument takes precedence over startAfterDocument
  final DocumentSnapshot? startAtDocument;
  final List<Object>? startAt;
  final Widget? header;
  final Widget? footer;

  /// Use this only if `isLive = false`
  final GetOptions? options;

  /// Use this only if `isLive = true`
  final bool includeMetadataChanges;

  @override
  _PaginateFirestoreState createState() => _PaginateFirestoreState();

  final Widget Function(Exception)? onError;

  final Widget Function(BuildContext, List<DocumentSnapshot>, int) itemBuilder;

  final void Function(PaginationLoaded)? onReachedEnd;

  final void Function(PaginationLoaded)? onLoaded;

  final void Function(int)? onPageChanged;
}

class _PaginateFirestoreState extends State<PaginateFirestore> {
  PaginationCubit? _cubit;
  double? scrollExtent;
  double scrollOffset = 70;
  int currentItemIndex = 0;
  bool loading = false;
  int needsJumpToIndex = -1;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaginationCubit, PaginationState>(
      bloc: _cubit,
      builder: (context, state) {
        if (state is PaginationInitial) {
          return widget.initialLoader;
        } else if (state is PaginationError) {
          return (widget.onError != null)
              ? widget.onError!(state.error)
              : ErrorDisplay(exception: state.error);
        } else {
          final loadedState = state as PaginationLoaded;
          if (widget.onLoaded != null) {
            widget.onLoaded!(loadedState);
          }
          if (loadedState.hasReachedEnd && widget.onReachedEnd != null) {
            widget.onReachedEnd!(loadedState);
          }

          if (loadedState.top.isEmpty && loadedState.bottom.isEmpty) {
            return widget.onEmpty;
          }
          return widget.itemBuilderType == PaginateBuilderType.listView
              ? _buildListView(loadedState)
              : widget.itemBuilderType == PaginateBuilderType.gridView
                  ? _buildGridView(loadedState)
                  : _buildPageView(loadedState);
        }
      },
    );
  }

  @override
  void dispose() {
    widget.scrollController?.dispose();
    _cubit?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    if (widget.listeners != null) {
      for (var listener in widget.listeners!) {
        if (listener is PaginateRefreshedChangeListener) {
          listener.addListener(() {
            if (listener.refreshed) {
              _cubit!.refreshPaginatedList(direction: PaginationDirection.next);
              _cubit!.refreshPaginatedList(
                  direction: PaginationDirection.previous);
            }
          });
        } else if (listener is PaginateFilterChangeListener) {
          listener.addListener(() {
            if (listener.searchTerm.isNotEmpty) {
              _cubit!.filterPaginatedList(listener.searchTerm);
            }
          });
        }
      }
    }

    _cubit = PaginationCubit(
      widget.query,
      widget.itemsPerPage,
      widget.startAfterDocument,
      widget.startAtDocument,
      widget.startAt,
      isLive: widget.isLive,
    )..fetchPaginatedList();

    super.initState();
  }

  Widget _buildGridView(PaginationLoaded loadedState) {
    return SizedBox();
    // var gridView = CustomScrollView(
    //   reverse: widget.reverse,
    //   controller: widget.scrollController,
    //   shrinkWrap: widget.shrinkWrap,
    //   scrollDirection: widget.scrollDirection,
    //   physics: widget.physics,
    //   slivers: [
    //     if (widget.header != null) widget.header!,
    //     SliverPadding(
    //       padding: widget.padding,
    //       sliver: SliverGrid(
    //         gridDelegate: widget.gridDelegate,
    //         delegate: SliverChildBuilderDelegate(
    //           (context, index) {
    //             if (index >= loadedState.documentSnapshots.length) {
    //               _cubit!.fetchPaginatedList();
    //               return widget.bottomLoader;
    //             }
    //             return widget.itemBuilder(
    //               context,
    //               loadedState.documentSnapshots,
    //               index,
    //             );
    //           },
    //           childCount: loadedState.hasReachedEnd
    //               ? loadedState.documentSnapshots.length
    //               : loadedState.documentSnapshots.length + 1,
    //         ),
    //       ),
    //     ),
    //     if (widget.footer != null) widget.footer!,
    //   ],
    // );

    // if (widget.listeners != null && widget.listeners!.isNotEmpty) {
    //   return MultiProvider(
    //     providers: widget.listeners!
    //         .map((_listener) => ChangeNotifierProvider(
    //               create: (context) => _listener,
    //             ))
    //         .toList(),
    //     child: gridView,
    //   );
    // }

    // return gridView;
  }

  bool _hasStartingCursors() {
    return widget.startAt != null ||
        widget.startAtDocument != null ||
        widget.startAfterDocument != null;
  }

  Widget _buildListView(PaginationLoaded loadedState) {
    const Key centerKey = ValueKey<String>('pagination-sliver-list');

    var listView = CustomScrollView(
      reverse: widget.reverse,
      controller: widget.scrollController,
      shrinkWrap: widget.shrinkWrap,
      center: centerKey,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      slivers: [
        if (widget.header != null)
          SliverPadding(
              padding: EdgeInsets.zero,
              key: !_hasStartingCursors() ? centerKey : null,
              sliver: widget.header!),
        SliverPadding(
          key: !_hasStartingCursors() && widget.header == null
              ? centerKey
              : null,
          padding: EdgeInsets.only(
              top: widget.padding.top,
              left: widget.padding.left,
              right: widget.padding.right),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final itemIndex = index ~/ 2;

                if (index.isEven) {
                  if (itemIndex >= loadedState.top.length) {
                    _cubit!.fetchPaginatedList(
                        direction: PaginationDirection.previous);
                    return widget.bottomLoader;
                  }
                  return widget.itemBuilder(
                    context,
                    loadedState.top,
                    loadedState.top.length - itemIndex - 1,
                  );
                }
                return widget.separator;
              },
              semanticIndexCallback: (widget, localIndex) {
                if (localIndex.isEven) {
                  return localIndex ~/ 2;
                }
                // ignore: avoid_returning_null
                return null;
              },
              childCount: max(
                  0,
                  (loadedState.hasReachedBeginning
                              ? loadedState.top.length
                              : loadedState.top.length + 1) *
                          2 -
                      1),
            ),
          ),
        ),
        SliverPadding(
          key: _hasStartingCursors() ? centerKey : null,
          padding: EdgeInsets.only(
              bottom: widget.padding.bottom,
              left: widget.padding.left,
              right: widget.padding.right),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final itemIndex = index ~/ 2;
                if (index.isEven) {
                  if (itemIndex >= loadedState.bottom.length) {
                    _cubit!.fetchPaginatedList();
                    return widget.bottomLoader;
                  }
                  return widget.itemBuilder(
                    context,
                    loadedState.bottom,
                    itemIndex,
                  );
                }
                return widget.separator;
              },
              semanticIndexCallback: (widget, localIndex) {
                if (localIndex.isEven) {
                  return localIndex ~/ 2;
                }
                // ignore: avoid_returning_null
                return null;
              },
              childCount: max(
                  0,
                  (loadedState.hasReachedEnd
                              ? loadedState.bottom.length
                              : loadedState.bottom.length + 1) *
                          2 -
                      1),
            ),
          ),
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );

    if (widget.listeners != null && widget.listeners!.isNotEmpty) {
      return MultiProvider(
        providers: widget.listeners!
            .map((_listener) => ChangeNotifierProvider(
                  create: (context) => _listener,
                ))
            .toList(),
        child: listView,
      );
    }

    return listView;
  }

  static const initialPage =
      232304; // an arbitrary large number to allow for negative scrolling.
  final PageController _pageController =
      PageController(initialPage: initialPage);

  // Note that the page view doesn't stop scrolling once you reach the
  // edges of your data.
  Widget _buildPageView(PaginationLoaded loadedState) {
    var pageView = Padding(
      padding: widget.padding,
      child: PageView.custom(
        reverse: widget.reverse,
        allowImplicitScrolling: widget.allowImplicitScrolling,
        controller: widget.pageController ?? _pageController,
        scrollDirection: widget.scrollDirection,
        physics: widget.physics,
        onPageChanged: widget.onPageChanged,
        childrenDelegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= initialPage) {
              // render from bottom
              final itemIndex = index - initialPage;
              if (itemIndex >= loadedState.bottom.length) {
                _cubit!.fetchPaginatedList();
                return loadedState.hasReachedEnd ? null : widget.bottomLoader;
              }
              return widget.itemBuilder(
                context,
                loadedState.bottom,
                itemIndex,
              );
            } else {
              // render from top
              final itemIndex = initialPage - index - 1;

              if (itemIndex >= loadedState.top.length) {
                _cubit!.fetchPaginatedList(
                    direction: PaginationDirection.previous);
                return loadedState.hasReachedBeginning
                    ? null
                    : widget.bottomLoader;
              }

              return widget.itemBuilder(
                context,
                loadedState.top,
                loadedState.top.length - itemIndex - 1,
              );
            }
          },
        ),
      ),
    );

    if (widget.listeners != null && widget.listeners!.isNotEmpty) {
      return MultiProvider(
        providers: widget.listeners!
            .map((_listener) => ChangeNotifierProvider(
                  create: (context) => _listener,
                ))
            .toList(),
        child: pageView,
      );
    }

    return pageView;
  }
}

enum PaginateBuilderType { listView, gridView, pageView }
