import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Page lengths offered on every list. Ten is the starting length.
const pageSizeChoices = [10, 20, 50];

/// Previous, next, and a choice of how many rows to show.
class PageBar extends StatelessWidget {
  const PageBar({
    super.key,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.onPage,
    required this.onPageSize,
  });

  final int count;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onPageSize;

  @override
  Widget build(BuildContext context) {
    if (count <= pageSizeChoices.first && pageSize == pageSizeChoices.first) {
      return const SizedBox.shrink();
    }
    final pages = math.max(1, (count / pageSize).ceil());
    final current = page.clamp(0, pages - 1);
    final start = current * pageSize;
    final end = math.min(start + pageSize, count);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          TextButton(
            onPressed: current == 0 ? null : () => onPage(current - 1),
            child: const Text('Previous'),
          ),
          Text('${start + 1}–$end of $count'),
          TextButton(
            onPressed: current >= pages - 1 ? null : () => onPage(current + 1),
            child: const Text('Next'),
          ),
          const Text('Show'),
          for (final choice in pageSizeChoices)
            TextButton(
              onPressed: pageSize == choice ? null : () => onPageSize(choice),
              child: Text('$choice'),
            ),
        ],
      ),
    );
  }
}

/// A list or table that turns its own pages, and scrolls inside its own box.
class PageBox extends StatefulWidget {
  const PageBox({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.pageSize = 10,
    this.height = 360,
    this.header,
    this.scrollKey,
    this.resetToken,
  });

  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final int pageSize;
  final double height;
  final Widget? header;
  final Key? scrollKey;

  /// When this changes, the list goes back to the first page.
  final Object? resetToken;

  @override
  State<PageBox> createState() => _PageBoxState();
}

class _PageBoxState extends State<PageBox> {
  int _page = 0;
  late int _size = widget.pageSize;

  @override
  void didUpdateWidget(PageBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = math.max(1, (widget.count / _size).ceil());
    final page = _page.clamp(0, pages - 1);
    final start = page * _size;
    final end = math.min(start + _size, widget.count);
    final boxed = widget.count > _size;
    final list = ListView(
      key: widget.scrollKey,
      primary: false,
      shrinkWrap: !boxed,
      physics: boxed
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      children: [
        if (widget.header != null) widget.header!,
        for (var index = start; index < end; index++)
          widget.itemBuilder(context, index),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (boxed) SizedBox(height: widget.height, child: list) else list,
        PageBar(
          count: widget.count,
          page: page,
          pageSize: _size,
          onPage: (next) => setState(() => _page = next),
          onPageSize: (size) => setState(() {
            _size = size;
            _page = 0;
          }),
        ),
      ],
    );
  }
}
