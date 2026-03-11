import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/theme.dart';

/// Screen for logged-in users to apply to become a travel expert.
/// Shows disclaimer, 50/50 revenue note, and application form.
class TravelExpertApplyScreen extends StatefulWidget {
  const TravelExpertApplyScreen({super.key});

  @override
  State<TravelExpertApplyScreen> createState() => _TravelExpertApplyScreenState();
}

class _TravelExpertApplyScreenState extends State<TravelExpertApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripIdeaCtrl = TextEditingController();
  final _whyExpertCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _pinterestCtrl = TextEditingController();
  final _otherLinksCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _tripIdeaCtrl.dispose();
    _whyExpertCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _pinterestCtrl.dispose();
    _otherLinksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      // TODO: Persist to Firestore (e.g. builder_applications) or send to backend
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Application received. We’ll get back to you soon.'),
          backgroundColor: context.colors.primary,
        ),
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Become a travel expert'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDisclaimerCard(context),
                const SizedBox(height: 20),
                _buildRevenueNote(context),
                const SizedBox(height: 24),
                Text(
                  'Application',
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BrandingLightTokens.formLabel,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _tripIdeaCtrl,
                  label: 'Describe your trip idea',
                  hint: 'What kind of trips or routes would you like to create? What makes your perspective unique?',
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe your trip idea' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _whyExpertCtrl,
                  label: 'Why should you become a travel expert?',
                  hint: 'Share your experience organising trips, travel blogging, or other relevant background.',
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please tell us why you’re a good fit' : null,
                ),
                const SizedBox(height: 16),
                Text(
                  'Social & links (optional)',
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: BrandingLightTokens.formLabel,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _instagramCtrl,
                  label: 'Instagram',
                  hint: 'https://instagram.com/...',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _tiktokCtrl,
                  label: 'TikTok',
                  hint: 'https://tiktok.com/...',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _pinterestCtrl,
                  label: 'Pinterest',
                  hint: 'https://pinterest.com/...',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _otherLinksCtrl,
                  label: 'Other links',
                  hint: 'Blog, YouTube, website…',
                  maxLines: 2,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onPrimary,
                          ),
                        )
                      : const Text('Submit application'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: context.colors.primary),
              const SizedBox(width: 8),
              Text(
                'Please note',
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'We accept a limited number of travel experts. We look for people who are willing to invest time and effort in creating high-quality plans, and who have a strong background in travel—such as experience organising trips, travel blogging or content creation, or another proven track record in the travel space.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.savings_outlined, size: 22, color: context.colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Our marketplace splits revenue 50/50 with travel experts: you earn half of each sale of your plans.',
              style: context.textStyles.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.colors.onSurface,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textStyles.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: BrandingLightTokens.formLabel,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: BrandingLightTokens.hint, fontSize: 14),
            filled: true,
            fillColor: BrandingLightTokens.formFieldBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: BrandingLightTokens.formFieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: BrandingLightTokens.formFieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: context.colors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
