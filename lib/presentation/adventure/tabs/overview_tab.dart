import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/adventure_context_model.dart';
import 'package:waypoint/state/adventure_form_state.dart';
import 'package:waypoint/components/unified/section_card.dart';
import 'package:waypoint/components/adventure/adventure_tags_row.dart';
import 'package:waypoint/components/adventure/creator_card.dart';
import 'package:waypoint/components/adventure/version_carousel.dart';
import 'package:waypoint/components/unified/inline_editable_field.dart';
import 'package:waypoint/components/unified/inline_editable_dropdown.dart';
import 'package:waypoint/layout/responsive_content_layout.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/user_service.dart';

/// Overview tab for builder mode
class BuilderOverviewTab extends StatelessWidget {
  final AdventureFormState formState;
  final Future<UserModel?>? creatorUserFuture;
  final VoidCallback onAddVersion;
  final Function(int) onEditVersion;
  final Function(int) onDeleteVersion;
  final Function(int) onSelectVersion;
  final Function() onShowVersionEditModal;

  const BuilderOverviewTab({
    super.key,
    required this.formState,
    this.creatorUserFuture,
    required this.onAddVersion,
    required this.onEditVersion,
    required this.onDeleteVersion,
    required this.onSelectVersion,
    required this.onShowVersionEditModal,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: formState,
      builder: (context, _) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: ResponsiveContentLayout(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note: Hero image, title, description building methods
                // would need to be passed as callbacks or extracted further
                // For now, this is a placeholder structure
                const SizedBox(height: WaypointSpacing.sectionGap),
                
                // Tags Row
                AdventureTagsRow(formState: formState),
                const SizedBox(height: WaypointSpacing.subsectionGap),
                
                // Version Carousel
                VersionCarousel(
                  versions: formState.versions,
                  activeIndex: formState.activeVersionIndex,
                  onSelect: (index) {
                    formState.activeVersionIndex = index;
                    onSelectVersion(index);
                  },
                  onAddVersion: onAddVersion,
                  onEdit: onEditVersion,
                  onDelete: onDeleteVersion,
                  isBuilder: true,
                  activityCategory: formState.activityCategory,
                ),
                const SizedBox(height: WaypointSpacing.subsectionGap),
                
                // Creator Card
                if (creatorUserFuture != null)
                  FutureBuilder<UserModel?>(
                    future: creatorUserFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final user = snapshot.data!;
                        final creatorId = formState.editingPlan?.creatorId;
                        return CreatorCard(
                          avatarUrl: user.photoUrl,
                          name: user.displayName,
                          bio: user.shortBio,
                          creatorId: creatorId,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                const SizedBox(height: WaypointSpacing.sectionGap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

