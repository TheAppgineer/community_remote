// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'roon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$RoonEvent {
  String get field0 => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $RoonEventCopyWith<RoonEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoonEventCopyWith<$Res> {
  factory $RoonEventCopyWith(RoonEvent value, $Res Function(RoonEvent) then) =
      _$RoonEventCopyWithImpl<$Res, RoonEvent>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class _$RoonEventCopyWithImpl<$Res, $Val extends RoonEvent>
    implements $RoonEventCopyWith<$Res> {
  _$RoonEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_value.copyWith(
      field0: null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RoonEvent_CoreFoundImplCopyWith<$Res>
    implements $RoonEventCopyWith<$Res> {
  factory _$$RoonEvent_CoreFoundImplCopyWith(_$RoonEvent_CoreFoundImpl value,
          $Res Function(_$RoonEvent_CoreFoundImpl) then) =
      __$$RoonEvent_CoreFoundImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$RoonEvent_CoreFoundImplCopyWithImpl<$Res>
    extends _$RoonEventCopyWithImpl<$Res, _$RoonEvent_CoreFoundImpl>
    implements _$$RoonEvent_CoreFoundImplCopyWith<$Res> {
  __$$RoonEvent_CoreFoundImplCopyWithImpl(_$RoonEvent_CoreFoundImpl _value,
      $Res Function(_$RoonEvent_CoreFoundImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$RoonEvent_CoreFoundImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$RoonEvent_CoreFoundImpl implements RoonEvent_CoreFound {
  const _$RoonEvent_CoreFoundImpl(this.field0);

  @override
  final String field0;

  @override
  String toString() {
    return 'RoonEvent.coreFound(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoonEvent_CoreFoundImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoonEvent_CoreFoundImplCopyWith<_$RoonEvent_CoreFoundImpl> get copyWith =>
      __$$RoonEvent_CoreFoundImplCopyWithImpl<_$RoonEvent_CoreFoundImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
  }) {
    return coreFound(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
  }) {
    return coreFound?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    required TResult orElse(),
  }) {
    if (coreFound != null) {
      return coreFound(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
  }) {
    return coreFound(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
  }) {
    return coreFound?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    required TResult orElse(),
  }) {
    if (coreFound != null) {
      return coreFound(this);
    }
    return orElse();
  }
}

abstract class RoonEvent_CoreFound implements RoonEvent {
  const factory RoonEvent_CoreFound(final String field0) =
      _$RoonEvent_CoreFoundImpl;

  @override
  String get field0;
  @override
  @JsonKey(ignore: true)
  _$$RoonEvent_CoreFoundImplCopyWith<_$RoonEvent_CoreFoundImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RoonEvent_CoreLostImplCopyWith<$Res>
    implements $RoonEventCopyWith<$Res> {
  factory _$$RoonEvent_CoreLostImplCopyWith(_$RoonEvent_CoreLostImpl value,
          $Res Function(_$RoonEvent_CoreLostImpl) then) =
      __$$RoonEvent_CoreLostImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$RoonEvent_CoreLostImplCopyWithImpl<$Res>
    extends _$RoonEventCopyWithImpl<$Res, _$RoonEvent_CoreLostImpl>
    implements _$$RoonEvent_CoreLostImplCopyWith<$Res> {
  __$$RoonEvent_CoreLostImplCopyWithImpl(_$RoonEvent_CoreLostImpl _value,
      $Res Function(_$RoonEvent_CoreLostImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$RoonEvent_CoreLostImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$RoonEvent_CoreLostImpl implements RoonEvent_CoreLost {
  const _$RoonEvent_CoreLostImpl(this.field0);

  @override
  final String field0;

  @override
  String toString() {
    return 'RoonEvent.coreLost(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoonEvent_CoreLostImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoonEvent_CoreLostImplCopyWith<_$RoonEvent_CoreLostImpl> get copyWith =>
      __$$RoonEvent_CoreLostImplCopyWithImpl<_$RoonEvent_CoreLostImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
  }) {
    return coreLost(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
  }) {
    return coreLost?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    required TResult orElse(),
  }) {
    if (coreLost != null) {
      return coreLost(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
  }) {
    return coreLost(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
  }) {
    return coreLost?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    required TResult orElse(),
  }) {
    if (coreLost != null) {
      return coreLost(this);
    }
    return orElse();
  }
}

abstract class RoonEvent_CoreLost implements RoonEvent {
  const factory RoonEvent_CoreLost(final String field0) =
      _$RoonEvent_CoreLostImpl;

  @override
  String get field0;
  @override
  @JsonKey(ignore: true)
  _$$RoonEvent_CoreLostImplCopyWith<_$RoonEvent_CoreLostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
