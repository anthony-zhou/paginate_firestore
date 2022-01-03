part of 'pagination_cubit.dart';

@immutable
abstract class PaginationState {}

class PaginationInitial extends PaginationState {}

class PaginationError extends PaginationState {
  final Exception error;
  PaginationError({required this.error});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaginationError && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;
}

class PaginationLoaded extends PaginationState {
  PaginationLoaded({
    required this.top,
    required this.bottom,
    required this.hasReachedEnd,
    required this.hasReachedBeginning,
  });

  final bool hasReachedBeginning;
  final bool hasReachedEnd;
  final List<QueryDocumentSnapshot> top;
  final List<QueryDocumentSnapshot> bottom;

  PaginationLoaded copyWith({
    bool? hasReachedEnd,
    bool? hasReachedBeginning,
    List<QueryDocumentSnapshot>? top,
    List<QueryDocumentSnapshot>? bottom,
  }) {
    return PaginationLoaded(
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      hasReachedBeginning: hasReachedEnd ?? this.hasReachedBeginning,
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaginationLoaded &&
        other.hasReachedEnd == hasReachedEnd &&
        other.hasReachedBeginning == hasReachedBeginning &&
        listEquals(other.top, top) &&
        listEquals(other.bottom, bottom);
  }

  @override
  int get hashCode =>
      hasReachedEnd.hashCode ^
      hasReachedBeginning.hashCode ^
      top.hashCode ^
      bottom.hashCode;
}
