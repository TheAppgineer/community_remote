// This file is automatically generated, so please do not edit it.
// Generated by `flutter_rust_bridge`@ 2.3.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import '../frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class BrowseItem {
  final String title;
  final String? subtitle;
  final String? imageKey;
  final String? itemKey;
  final BrowseItemHint? hint;
  final InputPrompt? inputPrompt;

  const BrowseItem({
    required this.title,
    this.subtitle,
    this.imageKey,
    this.itemKey,
    this.hint,
    this.inputPrompt,
  });

  @override
  int get hashCode =>
      title.hashCode ^
      subtitle.hashCode ^
      imageKey.hashCode ^
      itemKey.hashCode ^
      hint.hashCode ^
      inputPrompt.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowseItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          subtitle == other.subtitle &&
          imageKey == other.imageKey &&
          itemKey == other.itemKey &&
          hint == other.hint &&
          inputPrompt == other.inputPrompt;
}

enum BrowseItemHint {
  none,
  action,
  actionList,
  list,
  header,
  ;
}

class BrowseList {
  final String title;
  final BigInt count;
  final int level;
  final String? subtitle;
  final String? imageKey;
  final BigInt? displayOffset;
  final BrowseListHint? hint;

  const BrowseList({
    required this.title,
    required this.count,
    required this.level,
    this.subtitle,
    this.imageKey,
    this.displayOffset,
    this.hint,
  });

  @override
  int get hashCode =>
      title.hashCode ^
      count.hashCode ^
      level.hashCode ^
      subtitle.hashCode ^
      imageKey.hashCode ^
      displayOffset.hashCode ^
      hint.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowseList &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          count == other.count &&
          level == other.level &&
          subtitle == other.subtitle &&
          imageKey == other.imageKey &&
          displayOffset == other.displayOffset &&
          hint == other.hint;
}

enum BrowseListHint {
  none,
  actionList,
  ;
}

class InputPrompt {
  final String prompt;
  final String action;
  final String? value;
  final bool? isPassword;

  const InputPrompt({
    required this.prompt,
    required this.action,
    this.value,
    this.isPassword,
  });

  @override
  int get hashCode =>
      prompt.hashCode ^ action.hashCode ^ value.hashCode ^ isPassword.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputPrompt &&
          runtimeType == other.runtimeType &&
          prompt == other.prompt &&
          action == other.action &&
          value == other.value &&
          isPassword == other.isPassword;
}
