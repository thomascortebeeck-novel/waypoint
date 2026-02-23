import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/spacing.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';

class ResponsiveContentLayout extends StatelessWidget {
  final Widget content;
  final Widget? sidebar;

  const ResponsiveContentLayout({
    super.key,
    required this.content,
    this.sidebar,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = WaypointBreakpoints.isDesktop(width);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: WaypointSpacing.layoutMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop
                ? WaypointSpacing.contentHPadding
                : WaypointSpacing.pagePaddingMobile.horizontal,
          ),
          child: isDesktop && sidebar != null
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content — constrained to 900px max
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: WaypointSpacing.contentMaxWidth,
                        ),
                        child: content,
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Sidebar — fixed 280px, sticky via SliverPersistentHeader
                    // For now: plain top-aligned
                    SizedBox(
                      width: WaypointSpacing.sidebarWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: sidebar!,
                      ),
                    ),
                  ],
                )
              : content,
        ),
      ),
    );
  }
}
