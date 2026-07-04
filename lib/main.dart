import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/chat/data/bmo_rich_registry.dart';
import 'features/chat/widgets/bmo_rich_image_card.dart';

void main() {
  BmoRichRegistry.register('image', (block) => BmoRichImageCard(block: block));
  runApp(const ProviderScope(child: BmoApp()));
}
