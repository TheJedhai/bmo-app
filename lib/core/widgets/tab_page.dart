// Wrap each tab content with this. keepAlive=true preserves state across tab
// switches (used for Chat, Missoes). keepAlive=false rebuilds on every visit
// (used for Home and dashboards that should refresh).
import 'package:flutter/material.dart';

class TabPage extends StatefulWidget {
  final Widget child;
  final bool keepAlive;

  const TabPage({super.key, required this.child, required this.keepAlive});

  @override
  State<TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<TabPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
