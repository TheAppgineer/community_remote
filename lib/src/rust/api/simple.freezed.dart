// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'simple.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$RoonEvent {
  Object get field0 => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoonEventCopyWith<$Res> {
  factory $RoonEventCopyWith(RoonEvent value, $Res Function(RoonEvent) then) =
      _$RoonEventCopyWithImpl<$Res, RoonEvent>;
}

/// @nodoc
class _$RoonEventCopyWithImpl<$Res, $Val extends RoonEvent>
    implements $RoonEventCopyWith<$Res> {
  _$RoonEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$RoonEvent_CoreFoundImplCopyWith<$Res> {
  factory _$$RoonEvent_CoreFoundImplCopyWith(_$RoonEvent_CoreFoundImpl value,
          $Res Function(_$RoonEvent_CoreFoundImpl) then) =
      __$$RoonEvent_CoreFoundImplCopyWithImpl<$Res>;
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
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) {
    return coreFound(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) {
    return coreFound?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
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
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) {
    return coreFound(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) {
    return coreFound?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
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
  @JsonKey(ignore: true)
  _$$RoonEvent_CoreFoundImplCopyWith<_$RoonEvent_CoreFoundImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RoonEvent_CoreLostImplCopyWith<$Res> {
  factory _$$RoonEvent_CoreLostImplCopyWith(_$RoonEvent_CoreLostImpl value,
          $Res Function(_$RoonEvent_CoreLostImpl) then) =
      __$$RoonEvent_CoreLostImplCopyWithImpl<$Res>;
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
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) {
    return coreLost(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) {
    return coreLost?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
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
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) {
    return coreLost(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) {
    return coreLost?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
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
  @JsonKey(ignore: true)
  _$$RoonEvent_CoreLostImplCopyWith<_$RoonEvent_CoreLostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RoonEvent_ZonesChangedImplCopyWith<$Res> {
  factory _$$RoonEvent_ZonesChangedImplCopyWith(
          _$RoonEvent_ZonesChangedImpl value,
          $Res Function(_$RoonEvent_ZonesChangedImpl) then) =
      __$$RoonEvent_ZonesChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<ZoneSummary> field0});
}

/// @nodoc
class __$$RoonEvent_ZonesChangedImplCopyWithImpl<$Res>
    extends _$RoonEventCopyWithImpl<$Res, _$RoonEvent_ZonesChangedImpl>
    implements _$$RoonEvent_ZonesChangedImplCopyWith<$Res> {
  __$$RoonEvent_ZonesChangedImplCopyWithImpl(
      _$RoonEvent_ZonesChangedImpl _value,
      $Res Function(_$RoonEvent_ZonesChangedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$RoonEvent_ZonesChangedImpl(
      null == field0
          ? _value._field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as List<ZoneSummary>,
    ));
  }
}

/// @nodoc

class _$RoonEvent_ZonesChangedImpl implements RoonEvent_ZonesChanged {
  const _$RoonEvent_ZonesChangedImpl(final List<ZoneSummary> field0)
      : _field0 = field0;

  final List<ZoneSummary> _field0;
  @override
  List<ZoneSummary> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'RoonEvent.zonesChanged(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoonEvent_ZonesChangedImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoonEvent_ZonesChangedImplCopyWith<_$RoonEvent_ZonesChangedImpl>
      get copyWith => __$$RoonEvent_ZonesChangedImplCopyWithImpl<
          _$RoonEvent_ZonesChangedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) {
    return zonesChanged(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) {
    return zonesChanged?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
    required TResult orElse(),
  }) {
    if (zonesChanged != null) {
      return zonesChanged(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) {
    return zonesChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) {
    return zonesChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
    required TResult orElse(),
  }) {
    if (zonesChanged != null) {
      return zonesChanged(this);
    }
    return orElse();
  }
}

abstract class RoonEvent_ZonesChanged implements RoonEvent {
  const factory RoonEvent_ZonesChanged(final List<ZoneSummary> field0) =
      _$RoonEvent_ZonesChangedImpl;

  @override
  List<ZoneSummary> get field0;
  @JsonKey(ignore: true)
  _$$RoonEvent_ZonesChangedImplCopyWith<_$RoonEvent_ZonesChangedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RoonEvent_ZoneSelectedImplCopyWith<$Res> {
  factory _$$RoonEvent_ZoneSelectedImplCopyWith(
          _$RoonEvent_ZoneSelectedImpl value,
          $Res Function(_$RoonEvent_ZoneSelectedImpl) then) =
      __$$RoonEvent_ZoneSelectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({RoonZone field0});
}

/// @nodoc
class __$$RoonEvent_ZoneSelectedImplCopyWithImpl<$Res>
    extends _$RoonEventCopyWithImpl<$Res, _$RoonEvent_ZoneSelectedImpl>
    implements _$$RoonEvent_ZoneSelectedImplCopyWith<$Res> {
  __$$RoonEvent_ZoneSelectedImplCopyWithImpl(
      _$RoonEvent_ZoneSelectedImpl _value,
      $Res Function(_$RoonEvent_ZoneSelectedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$RoonEvent_ZoneSelectedImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as RoonZone,
    ));
  }
}

/// @nodoc

class _$RoonEvent_ZoneSelectedImpl implements RoonEvent_ZoneSelected {
  const _$RoonEvent_ZoneSelectedImpl(this.field0);

  @override
  final RoonZone field0;

  @override
  String toString() {
    return 'RoonEvent.zoneSelected(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoonEvent_ZoneSelectedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoonEvent_ZoneSelectedImplCopyWith<_$RoonEvent_ZoneSelectedImpl>
      get copyWith => __$$RoonEvent_ZoneSelectedImplCopyWithImpl<
          _$RoonEvent_ZoneSelectedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) {
    return zoneSelected(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) {
    return zoneSelected?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
    required TResult orElse(),
  }) {
    if (zoneSelected != null) {
      return zoneSelected(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) {
    return zoneSelected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) {
    return zoneSelected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
    required TResult orElse(),
  }) {
    if (zoneSelected != null) {
      return zoneSelected(this);
    }
    return orElse();
  }
}

abstract class RoonEvent_ZoneSelected implements RoonEvent {
  const factory RoonEvent_ZoneSelected(final RoonZone field0) =
      _$RoonEvent_ZoneSelectedImpl;

  @override
  RoonZone get field0;
  @JsonKey(ignore: true)
  _$$RoonEvent_ZoneSelectedImplCopyWith<_$RoonEvent_ZoneSelectedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RoonEvent_BrowseItemsImplCopyWith<$Res> {
  factory _$$RoonEvent_BrowseItemsImplCopyWith(
          _$RoonEvent_BrowseItemsImpl value,
          $Res Function(_$RoonEvent_BrowseItemsImpl) then) =
      __$$RoonEvent_BrowseItemsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({BrowseItems field0});
}

/// @nodoc
class __$$RoonEvent_BrowseItemsImplCopyWithImpl<$Res>
    extends _$RoonEventCopyWithImpl<$Res, _$RoonEvent_BrowseItemsImpl>
    implements _$$RoonEvent_BrowseItemsImplCopyWith<$Res> {
  __$$RoonEvent_BrowseItemsImplCopyWithImpl(_$RoonEvent_BrowseItemsImpl _value,
      $Res Function(_$RoonEvent_BrowseItemsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$RoonEvent_BrowseItemsImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as BrowseItems,
    ));
  }
}

/// @nodoc

class _$RoonEvent_BrowseItemsImpl implements RoonEvent_BrowseItems {
  const _$RoonEvent_BrowseItemsImpl(this.field0);

  @override
  final BrowseItems field0;

  @override
  String toString() {
    return 'RoonEvent.browseItems(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoonEvent_BrowseItemsImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoonEvent_BrowseItemsImplCopyWith<_$RoonEvent_BrowseItemsImpl>
      get copyWith => __$$RoonEvent_BrowseItemsImplCopyWithImpl<
          _$RoonEvent_BrowseItemsImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) {
    return browseItems(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) {
    return browseItems?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
    required TResult orElse(),
  }) {
    if (browseItems != null) {
      return browseItems(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) {
    return browseItems(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) {
    return browseItems?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
    required TResult orElse(),
  }) {
    if (browseItems != null) {
      return browseItems(this);
    }
    return orElse();
  }
}

abstract class RoonEvent_BrowseItems implements RoonEvent {
  const factory RoonEvent_BrowseItems(final BrowseItems field0) =
      _$RoonEvent_BrowseItemsImpl;

  @override
  BrowseItems get field0;
  @JsonKey(ignore: true)
  _$$RoonEvent_BrowseItemsImplCopyWith<_$RoonEvent_BrowseItemsImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RoonEvent_ImageImplCopyWith<$Res> {
  factory _$$RoonEvent_ImageImplCopyWith(_$RoonEvent_ImageImpl value,
          $Res Function(_$RoonEvent_ImageImpl) then) =
      __$$RoonEvent_ImageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ImageKeyValue field0});
}

/// @nodoc
class __$$RoonEvent_ImageImplCopyWithImpl<$Res>
    extends _$RoonEventCopyWithImpl<$Res, _$RoonEvent_ImageImpl>
    implements _$$RoonEvent_ImageImplCopyWith<$Res> {
  __$$RoonEvent_ImageImplCopyWithImpl(
      _$RoonEvent_ImageImpl _value, $Res Function(_$RoonEvent_ImageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$RoonEvent_ImageImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as ImageKeyValue,
    ));
  }
}

/// @nodoc

class _$RoonEvent_ImageImpl implements RoonEvent_Image {
  const _$RoonEvent_ImageImpl(this.field0);

  @override
  final ImageKeyValue field0;

  @override
  String toString() {
    return 'RoonEvent.image(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoonEvent_ImageImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoonEvent_ImageImplCopyWith<_$RoonEvent_ImageImpl> get copyWith =>
      __$$RoonEvent_ImageImplCopyWithImpl<_$RoonEvent_ImageImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) {
    return image(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) {
    return image?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
    required TResult orElse(),
  }) {
    if (image != null) {
      return image(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) {
    return image(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) {
    return image?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
    required TResult orElse(),
  }) {
    if (image != null) {
      return image(this);
    }
    return orElse();
  }
}

abstract class RoonEvent_Image implements RoonEvent {
  const factory RoonEvent_Image(final ImageKeyValue field0) =
      _$RoonEvent_ImageImpl;

  @override
  ImageKeyValue get field0;
  @JsonKey(ignore: true)
  _$$RoonEvent_ImageImplCopyWith<_$RoonEvent_ImageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RoonEvent_SettingsImplCopyWith<$Res> {
  factory _$$RoonEvent_SettingsImplCopyWith(_$RoonEvent_SettingsImpl value,
          $Res Function(_$RoonEvent_SettingsImpl) then) =
      __$$RoonEvent_SettingsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Settings field0});
}

/// @nodoc
class __$$RoonEvent_SettingsImplCopyWithImpl<$Res>
    extends _$RoonEventCopyWithImpl<$Res, _$RoonEvent_SettingsImpl>
    implements _$$RoonEvent_SettingsImplCopyWith<$Res> {
  __$$RoonEvent_SettingsImplCopyWithImpl(_$RoonEvent_SettingsImpl _value,
      $Res Function(_$RoonEvent_SettingsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$RoonEvent_SettingsImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as Settings,
    ));
  }
}

/// @nodoc

class _$RoonEvent_SettingsImpl implements RoonEvent_Settings {
  const _$RoonEvent_SettingsImpl(this.field0);

  @override
  final Settings field0;

  @override
  String toString() {
    return 'RoonEvent.settings(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoonEvent_SettingsImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoonEvent_SettingsImplCopyWith<_$RoonEvent_SettingsImpl> get copyWith =>
      __$$RoonEvent_SettingsImplCopyWithImpl<_$RoonEvent_SettingsImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) coreFound,
    required TResult Function(String field0) coreLost,
    required TResult Function(List<ZoneSummary> field0) zonesChanged,
    required TResult Function(RoonZone field0) zoneSelected,
    required TResult Function(BrowseItems field0) browseItems,
    required TResult Function(ImageKeyValue field0) image,
    required TResult Function(Settings field0) settings,
  }) {
    return settings(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? coreFound,
    TResult? Function(String field0)? coreLost,
    TResult? Function(List<ZoneSummary> field0)? zonesChanged,
    TResult? Function(RoonZone field0)? zoneSelected,
    TResult? Function(BrowseItems field0)? browseItems,
    TResult? Function(ImageKeyValue field0)? image,
    TResult? Function(Settings field0)? settings,
  }) {
    return settings?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? coreFound,
    TResult Function(String field0)? coreLost,
    TResult Function(List<ZoneSummary> field0)? zonesChanged,
    TResult Function(RoonZone field0)? zoneSelected,
    TResult Function(BrowseItems field0)? browseItems,
    TResult Function(ImageKeyValue field0)? image,
    TResult Function(Settings field0)? settings,
    required TResult orElse(),
  }) {
    if (settings != null) {
      return settings(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RoonEvent_CoreFound value) coreFound,
    required TResult Function(RoonEvent_CoreLost value) coreLost,
    required TResult Function(RoonEvent_ZonesChanged value) zonesChanged,
    required TResult Function(RoonEvent_ZoneSelected value) zoneSelected,
    required TResult Function(RoonEvent_BrowseItems value) browseItems,
    required TResult Function(RoonEvent_Image value) image,
    required TResult Function(RoonEvent_Settings value) settings,
  }) {
    return settings(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RoonEvent_CoreFound value)? coreFound,
    TResult? Function(RoonEvent_CoreLost value)? coreLost,
    TResult? Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult? Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult? Function(RoonEvent_BrowseItems value)? browseItems,
    TResult? Function(RoonEvent_Image value)? image,
    TResult? Function(RoonEvent_Settings value)? settings,
  }) {
    return settings?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RoonEvent_CoreFound value)? coreFound,
    TResult Function(RoonEvent_CoreLost value)? coreLost,
    TResult Function(RoonEvent_ZonesChanged value)? zonesChanged,
    TResult Function(RoonEvent_ZoneSelected value)? zoneSelected,
    TResult Function(RoonEvent_BrowseItems value)? browseItems,
    TResult Function(RoonEvent_Image value)? image,
    TResult Function(RoonEvent_Settings value)? settings,
    required TResult orElse(),
  }) {
    if (settings != null) {
      return settings(this);
    }
    return orElse();
  }
}

abstract class RoonEvent_Settings implements RoonEvent {
  const factory RoonEvent_Settings(final Settings field0) =
      _$RoonEvent_SettingsImpl;

  @override
  Settings get field0;
  @JsonKey(ignore: true)
  _$$RoonEvent_SettingsImplCopyWith<_$RoonEvent_SettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
