import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class RssView {
  const RssView();
}

class AllArticles extends RssView {
  const AllArticles();
}

class UnreadArticles extends RssView {
  const UnreadArticles();
}

class StarredArticles extends RssView {
  const StarredArticles();
}

class FeedView extends RssView {
  final int feedId;
  const FeedView(this.feedId);
}

class CurrentRssViewNotifier extends Notifier<RssView> {
  @override
  RssView build() => const AllArticles();

  void setView(RssView view) {
    state = view;
  }
}

final currentRssViewProvider =
    NotifierProvider<CurrentRssViewNotifier, RssView>(
  CurrentRssViewNotifier.new,
);
