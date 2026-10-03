import 'package:flutter/material.dart';

/// Keeps the profile pinned and reveals search when the reader scrolls back.
class HomeScrollLayout extends StatefulWidget {
  final Widget Function(bool searchVisible) headerBuilder;
  final Widget child;
  final double cornerOverlap;
  const HomeScrollLayout({
    super.key,
    required this.headerBuilder,
    required this.child,
    this.cornerOverlap = 0,
  });
  @override
  State<HomeScrollLayout> createState() => _HomeScrollLayoutState();
}

class _HomeScrollLayoutState extends State<HomeScrollLayout> {
  bool _searchVisible = true;
  double _travel = 0;
  bool _onScroll(ScrollNotification notification) {
    // Ignore nested/horizontal carousels and elastic overscroll.
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical ||
        notification.metrics.outOfRange) {
      return false;
    }
    if (notification is ScrollStartNotification) _travel = 0;
    if (notification is! ScrollUpdateNotification) return false;
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;
    if (_travel.sign != delta.sign) _travel = 0;
    _travel += delta;
    final atTop = notification.metrics.pixels <= 8;
    final show = atTop || _travel <= -16;
    final hide = notification.metrics.pixels > 48 && _travel >= 24;
    if (show && !_searchVisible) {
      setState(() => _searchVisible = true);
      _travel = 0;
    } else if (hide && _searchVisible && !atTop) {
      setState(() => _searchVisible = false);
      _travel = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _HomeHeaderLayout(widget.cornerOverlap),
    children: [
      LayoutId(
        id: _HomeSlot.content,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      ),
      // Paint the rounded header above the scrolling content, leaving its
      // corner cutouts transparent instead of reserving a solid strip.
      LayoutId(
        id: _HomeSlot.header,
        child: widget.headerBuilder(_searchVisible),
      ),
    ],
  );
}

enum _HomeSlot { header, content }

class _HomeHeaderLayout extends MultiChildLayoutDelegate {
  final double overlap;
  _HomeHeaderLayout(this.overlap);

  @override
  void performLayout(Size size) {
    final header = layoutChild(
      _HomeSlot.header,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: size.height,
      ),
    );
    final contentTop = (header.height - overlap).clamp(0.0, size.height);
    layoutChild(
      _HomeSlot.content,
      BoxConstraints.tight(Size(size.width, size.height - contentTop)),
    );
    positionChild(_HomeSlot.content, Offset(0, contentTop));
    positionChild(_HomeSlot.header, Offset.zero);
  }

  @override
  bool shouldRelayout(_HomeHeaderLayout oldDelegate) =>
      overlap != oldDelegate.overlap;
}
