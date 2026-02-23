import 'dart:html' as html;
import 'dart:convert' show jsonEncode;
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/utils/activity_config.dart';

/// Service for managing SEO meta tags and structured data
/// Only applies to plan detail pages (viewer mode)
class SeoService {
  static const String _siteName = 'Waypoint';
  static const String _baseUrl = 'https://waypoint.app'; // Update with actual domain
  
  /// Update meta tags for plan detail page
  static void updatePlanDetailMetaTags(Plan plan) {
    if (!kIsWeb) return; // Only for web
    
    final title = _generateTitle(plan);
    final description = _generateDescription(plan);
    final imageUrl = plan.heroImageUrl;
    final canonicalUrl = '$_baseUrl/details/${plan.id}';
    
    // Update title
    html.document.title = title;
    
    // Update or create meta tags
    _setMetaTag('description', description);
    _setMetaTag('og:title', title);
    _setMetaTag('og:description', description);
    _setMetaTag('og:image', imageUrl);
    _setMetaTag('og:url', canonicalUrl);
    _setMetaTag('og:type', 'website');
    _setMetaTag('og:site_name', _siteName);
    _setMetaTag('twitter:card', 'summary_large_image');
    _setMetaTag('twitter:title', title);
    _setMetaTag('twitter:description', description);
    _setMetaTag('twitter:image', imageUrl);
    
    // Canonical URL
    _setLinkTag('canonical', canonicalUrl);
    
    // Remove noindex if present (for published plans)
    if (plan.isPublished) {
      // Remove existing robots meta tag first
      final robotsSelector = 'meta[name="robots"]';
      html.document.querySelector(robotsSelector)?.remove();
      _setMetaTag('robots', 'index, follow');
    } else {
      _setMetaTag('robots', 'noindex, nofollow');
    }
    
    // Add structured data (JSON-LD)
    _addStructuredData(plan);
  }
  
  /// Clear SEO meta tags (for builder/trip modes)
  static void clearSeoMetaTags() {
    if (!kIsWeb) return;
    
    // Set default title
    html.document.title = _siteName;
    
    // Remove plan-specific meta tags
    _removeMetaTag('og:title');
    _removeMetaTag('og:description');
    _removeMetaTag('og:image');
    _removeMetaTag('og:url');
    _removeMetaTag('twitter:title');
    _removeMetaTag('twitter:description');
    _removeMetaTag('twitter:image');
    _removeLinkTag('canonical');
    
    // Add noindex for non-SEO pages
    _setMetaTag('robots', 'noindex, nofollow');
    
    // Remove structured data
    _removeStructuredData();
  }
  
  static String _generateTitle(Plan plan) {
    final location = plan.locations.isNotEmpty
        ? plan.locations.map((l) => l.shortName).join(', ')
        : plan.location;
    
    final activity = plan.activityCategory != null
        ? _getActivityDisplayName(plan.activityCategory!)
        : 'Adventure';
    
    return '$activity in $location - ${plan.name} | $_siteName';
  }
  
  static String _generateDescription(Plan plan) {
    // Use description, or generate from plan data
    if (plan.description.isNotEmpty) {
      // Truncate to ~155 characters for SEO
      return plan.description.length > 155
          ? '${plan.description.substring(0, 152)}...'
          : plan.description;
    }
    
    // Generate description from plan data
    final location = plan.locations.isNotEmpty
        ? plan.locations.map((l) => l.shortName).join(', ')
        : plan.location;
    
    final activity = plan.activityCategory != null
        ? _getActivityDisplayName(plan.activityCategory!)
        : 'adventure';
    
    final duration = plan.versions.isNotEmpty
        ? '${plan.versions.first.durationDays} day${plan.versions.first.durationDays != 1 ? 's' : ''}'
        : '';
    
    return 'Discover this $duration $activity in $location. ${plan.name} - Plan your next adventure with $_siteName.';
  }
  
  static String _getActivityDisplayName(ActivityCategory category) {
    final config = getActivityConfig(category);
    return config?.displayName ?? category.name;
  }
  
  static void _setMetaTag(String name, String content) {
    final selector = name.startsWith('og:') || name.startsWith('twitter:')
        ? 'meta[property="$name"]'
        : 'meta[name="$name"]';
    
    html.Element? element = html.document.querySelector(selector);
    
    if (element == null) {
      element = html.MetaElement();
      if (name.startsWith('og:') || name.startsWith('twitter:')) {
        element.setAttribute('property', name);
      } else {
        element.setAttribute('name', name);
      }
      html.document.head!.append(element);
    }
    
    element.setAttribute('content', content);
  }
  
  static void _removeMetaTag(String name) {
    final selector = name.startsWith('og:') || name.startsWith('twitter:')
        ? 'meta[property="$name"]'
        : 'meta[name="$name"]';
    html.document.querySelector(selector)?.remove();
  }
  
  static void _setLinkTag(String rel, String href) {
    html.Element? element = html.document.querySelector('link[rel="$rel"]');
    
    if (element == null) {
      element = html.LinkElement();
      element.setAttribute('rel', rel);
      html.document.head!.append(element);
    }
    
    element.setAttribute('href', href);
  }
  
  static void _removeLinkTag(String rel) {
    html.document.querySelector('link[rel="$rel"]')?.remove();
  }
  
  static void _addStructuredData(Plan plan) {
    // Remove existing structured data
    _removeStructuredData();
    
    // Create JSON-LD for Product
    final structuredData = <String, dynamic>{
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': plan.name,
      'description': plan.description.isNotEmpty 
          ? plan.description 
          : _generateDescription(plan),
      'image': plan.heroImageUrl,
      'brand': {
        '@type': 'Brand',
        'name': _siteName,
      },
      'offers': {
        '@type': 'Offer',
        'price': plan.basePrice.toStringAsFixed(2),
        'priceCurrency': 'EUR',
        'availability': plan.isPublished 
            ? 'https://schema.org/InStock' 
            : 'https://schema.org/OutOfStock',
        'url': '$_baseUrl/details/${plan.id}',
      },
    };
    
    // Add area served if locations exist
    if (plan.locations.isNotEmpty) {
      structuredData['areaServed'] = plan.locations.map((l) {
        final locationData = <String, dynamic>{
          '@type': 'City',
          'name': l.shortName,
        };
        if (l.latitude != null && l.longitude != null) {
          locationData['geo'] = {
            '@type': 'GeoCoordinates',
            'latitude': l.latitude,
            'longitude': l.longitude,
          };
        }
        return locationData;
      }).toList();
    }
    
    // Add category if activity exists
    if (plan.activityCategory != null) {
      structuredData['category'] = _getActivityDisplayName(plan.activityCategory!);
    }
    
    // Add aggregate rating if reviews exist
    if (plan.reviewStats != null) {
      structuredData['aggregateRating'] = {
        '@type': 'AggregateRating',
        'ratingValue': plan.reviewStats!.averageRating.toStringAsFixed(1),
        'reviewCount': plan.reviewStats!.totalReviews,
      };
    }
    
    final script = html.ScriptElement();
    script.setAttribute('type', 'application/ld+json');
    script.text = jsonEncode(structuredData);
    html.document.head!.append(script);
  }
  
  static void _removeStructuredData() {
    html.document.querySelectorAll('script[type="application/ld+json"]')
        .forEach((element) => element.remove());
  }
}

