import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waypoint/services/follow_service.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';

/// Reusable follow/unfollow button
/// Shows loading state during API call
/// Updates optimistically
class FollowButton extends StatefulWidget {
  final String creatorId;
  final String? currentUserId;
  final FollowService followService;

  const FollowButton({
    super.key,
    required this.creatorId,
    this.currentUserId,
    required this.followService,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (widget.currentUserId == null || widget.creatorId == widget.currentUserId) {
      setState(() {
        _isInitialized = true;
      });
      return;
    }

    try {
      final isFollowing = await widget.followService.isFollowing(
        widget.currentUserId!,
        widget.creatorId,
      );
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.currentUserId == null || widget.creatorId == widget.currentUserId) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isFollowing = !_isFollowing; // Optimistic update
    });

    try {
      if (_isFollowing) {
        await widget.followService.followCreator(
          widget.currentUserId!,
          widget.creatorId,
        );
      } else {
        await widget.followService.unfollowCreator(
          widget.currentUserId!,
          widget.creatorId,
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isFollowing ? 'follow' : 'unfollow'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show button if viewing own profile
    if (widget.currentUserId == widget.creatorId) {
      return const SizedBox.shrink();
    }

    // Don't show button if not logged in
    if (widget.currentUserId == null) {
      return const SizedBox.shrink();
    }

    if (!_isInitialized) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return _isFollowing
        ? OutlinedButton(
            onPressed: _isLoading ? null : _toggleFollow,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Following'),
          )
        : ElevatedButton(
            onPressed: _isLoading ? null : _toggleFollow,
            style: ElevatedButton.styleFrom(
              backgroundColor: WaypointColors.primary,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Follow'),
          );
  }
}

