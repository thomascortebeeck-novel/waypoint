import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/contact_service.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/storage_service.dart' show ImagePickResult, StorageService;
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';

/// Option for "Related plan or trip" dropdown (optional).
class _RelatedOption {
  final String label;
  final String? planId;
  final String? tripId;

  _RelatedOption({required this.label, this.planId, this.tripId});
}

/// Contact us page: form to submit questions to admins.
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _auth = FirebaseAuthManager();
  final _userService = UserService();
  final _tripService = TripService();
  final _planService = PlanService();
  final _contactService = ContactService();
  final _storageService = StorageService();

  List<_RelatedOption> _relatedOptions = [];
  _RelatedOption? _selectedRelated;
  bool _loadingOptions = true;
  bool _submitting = false;
  ImagePickResult? _screenshot;

  @override
  void initState() {
    super.initState();
    _loadRelatedOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRelatedOptions() async {
    final uid = _auth.currentUserId;
    if (uid == null) {
      setState(() {
        _relatedOptions = [_RelatedOption(label: 'None')];
        _loadingOptions = false;
      });
      return;
    }
    try {
      final user = await _userService.getUserById(uid);
      final planIds = <String>{
        ...?user?.purchasedPlanIds,
        ...?user?.invitedPlanIds,
      };
      final tripsSnapshot = await _tripService
          .streamTripsForUser(uid)
          .first;
      final trips = tripsSnapshot;
      for (final t in trips) {
        planIds.add(t.planId);
      }
      final plans = await _planService.getPlansByIds(planIds.toList());
      final planById = {for (final p in plans) p.id: p};

      final options = <_RelatedOption>[_RelatedOption(label: 'None')];
      for (final plan in plans) {
        if (user?.purchasedPlanIds.contains(plan.id) == true ||
            user?.invitedPlanIds.contains(plan.id) == true) {
          options.add(_RelatedOption(
            label: 'Plan: ${plan.name}',
            planId: plan.id,
          ));
        }
      }
      for (final trip in trips) {
        final plan = planById[trip.planId];
        final planTitle = plan?.name ?? trip.planId;
        options.add(_RelatedOption(
          label: 'Trip: ${trip.title ?? 'Untitled'} (Plan: $planTitle)',
          planId: trip.planId,
          tripId: trip.id,
        ));
      }
      if (mounted) {
        setState(() {
          _relatedOptions = options;
          _selectedRelated = options.first;
          _loadingOptions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _relatedOptions = [_RelatedOption(label: 'None')];
          _selectedRelated = _relatedOptions.first;
          _loadingOptions = false;
        });
      }
    }
  }

  Future<void> _pickScreenshot() async {
    final result = await _storageService.pickImage();
    if (result != null && mounted) {
      setState(() => _screenshot = result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to submit a request')),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final requestId = FirebaseFirestore.instance
          .collection('contact_requests')
          .doc()
          .id;
      String? screenshotUrl;
      if (_screenshot != null) {
        final ext = _screenshot!.extension == 'jpg' ? 'jpg' : 'png';
        screenshotUrl = await _storageService.uploadContactScreenshot(
          userId: uid,
          requestId: requestId,
          bytes: _screenshot!.bytes,
          contentType: ext == 'jpg' ? 'image/jpeg' : 'image/png',
          extension: ext,
        );
      }
      await _contactService.createContactRequest(
        userId: uid,
        userEmail: FirebaseAuth.instance.currentUser?.email,
        name: _nameController.text.trim(),
        relatedPlanId: _selectedRelated?.planId,
        relatedTripId: _selectedRelated?.tripId,
        description: _descriptionController.text.trim(),
        screenshotUrl: screenshotUrl,
        requestId: requestId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent. We\'ll get back to you soon.')),
      );
      context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUserId;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Contact us'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline, size: 64, color: context.colors.primary),
                const SizedBox(height: 16),
                Text(
                  'Sign in to contact us',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You need to be signed in to submit a question or feedback.',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/profile'),
                  child: const Text('Go to Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Contact us'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send us a message',
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Questions about a plan or trip? We\'re here to help.',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name of request *',
                  hintText: 'e.g. Payment issue, Bug report',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a name for your request';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_loadingOptions)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<_RelatedOption>(
                  value: _selectedRelated ?? _relatedOptions.first,
                  decoration: const InputDecoration(
                    labelText: 'Related plan or trip (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: _relatedOptions
                      .map((o) => DropdownMenuItem(
                            value: o,
                            child: Text(
                              o.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRelated = v),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe your question or issue...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickScreenshot,
                icon: const Icon(Icons.upload_file, size: 20),
                label: Text(_screenshot == null
                    ? 'Upload screenshot (optional)'
                    : 'Screenshot attached'),
              ),
              if (_screenshot != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Screenshot ready',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
