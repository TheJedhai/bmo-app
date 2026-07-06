// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rich_blocks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$richBlocksHash() => r'd896551bedf6e66a88a9e3de8216e51f19be4798';

/// Notifier that holds live state for every rich block currently on screen.
///
/// Keyed by [BmoRichBlock.blockId].  When a `rich.update` SSE event arrives,
/// [_applyPatch] mutates the entry in-place so only the corresponding card
/// rebuilds — no full-screen flicker.
///
/// Generic: image blocks today, question/CC blocks later.
///
/// Copied from [RichBlocks].
@ProviderFor(RichBlocks)
final richBlocksProvider =
    AutoDisposeNotifierProvider<
      RichBlocks,
      Map<String, RichBlockState>
    >.internal(
      RichBlocks.new,
      name: r'richBlocksProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$richBlocksHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RichBlocks = AutoDisposeNotifier<Map<String, RichBlockState>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
