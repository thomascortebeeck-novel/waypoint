// Comments/Questions tab
// This will be implemented in Phase 6: Comments System
// Placeholder structure for now

import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/comment_model.dart';
import 'package:waypoint/services/comment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Comments/Questions tab widget
/// Allows users to ask questions and creators to respond
class CommentsTab extends StatefulWidget {
  final String planId;
  final String? creatorId; // For checking if current user is creator
  final CommentService commentService;

  const CommentsTab({
    super.key,
    required this.planId,
    this.creatorId,
    required this.commentService,
  });

  @override
  State<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<CommentsTab> {
  List<Comment> _comments = [];
  bool _isLoading = true;
  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await widget.commentService.getComments(widget.planId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
    }
  }

  Future<void> _submitQuestion() async {
    final text = _questionController.text.trim();
    if (text.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to ask questions')),
      );
      return;
    }

    try {
      await widget.commentService.createComment(
        planId: widget.planId,
        text: text,
        isQuestion: true,
      );
      _questionController.clear();
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post question: $e')),
        );
      }
    }
  }

  Future<void> _submitReply(String commentId, String text) async {
    if (text.trim().isEmpty) return;

    try {
      await widget.commentService.createReply(commentId, text, widget.planId);
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reply: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = widget.creatorId != null && currentUserId == widget.creatorId;

    return Column(
      children: [
        // Question input (for non-creators)
        if (!isCreator)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask a Question',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _questionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ask the creator a question about this adventure...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _submitQuestion,
                  child: const Text('Post Question'),
                ),
              ],
            ),
          ),
        // Comments list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No questions yet. Be the first to ask!',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return _CommentCard(
                          comment: comment,
                          isCreator: isCreator,
                          onReply: (text) => _submitReply(comment.id, text),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final bool isCreator;
  final Function(String) onReply;

  const _CommentCard({
    required this.comment,
    required this.isCreator,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: comment.userAvatar != null
                      ? NetworkImage(comment.userAvatar!)
                      : null,
                  child: comment.userAvatar == null
                      ? Text(comment.userName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  comment.userName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (comment.isQuestion) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Question',
                      style: TextStyle(fontSize: 10, color: Colors.blue),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.text),
            if (comment.creatorResponse != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        const Text(
                          'Creator Response',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment.creatorResponse!),
                  ],
                ),
              ),
            ] else if (isCreator && comment.isQuestion) ...[
              const SizedBox(height: 8),
              _ReplyInput(onReply: onReply),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplyInput extends StatefulWidget {
  final Function(String) onReply;

  const _ReplyInput({required this.onReply});

  @override
  State<_ReplyInput> createState() => _ReplyInputState();
}

class _ReplyInputState extends State<_ReplyInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _isExpanded = true),
        icon: const Icon(Icons.reply, size: 16),
        label: const Text('Reply'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type your response...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isExpanded = false;
                  _controller.clear();
                });
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                widget.onReply(_controller.text);
                setState(() {
                  _isExpanded = false;
                  _controller.clear();
                });
              },
              child: const Text('Post Reply'),
            ),
          ],
        ),
      ],
    );
  }
}

