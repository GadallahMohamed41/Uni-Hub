import 'package:flutter/material.dart';

/// A reusable layout that displays a fixed sticky header at the top
/// and allows the rest of the body to scroll under it.
class StickyHeaderLayout extends StatelessWidget {
  final Widget header;
  final Widget body;

  const StickyHeaderLayout({
    super.key,
    required this.header,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        header,
        Expanded(
          child: body,
        ),
      ],
    );
  }
}
