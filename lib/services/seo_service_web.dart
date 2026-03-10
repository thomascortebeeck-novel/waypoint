import 'dart:html' as html;
import 'dart:convert' show jsonEncode;
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/utils/activity_config.dart';

/// Web implementation of SEO service (dart:html). Used only on web.
class SeoService {
  static const String _siteName = 'Waypoint';
  static const String _baseUrl = 'https://waypoint.app';

  static void updatePlanDetailMetaTags(Plan plan) {
    final title = _generateTitle(plan);
    final description = _generateDescription(plan);
    final imageUrl = plan.heroImageUrl;
    final canonicalUrl = '$_baseUrl/details/${plan.id}';

    html.document.title = title;
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
    _setLinkTag('canonical', canonicalUrl);

    if (plan.isPublished) {
      html.document.querySelector('meta[name="robots"]')?.remove();
      _setMetaTag('robots', 'index, follow');
    } else {
      _setMetaTag('robots', 'noindex, nofollow');
    }
    _addStructuredData(plan);
  }

  static void clearSeoMetaTags() {
    html.document.title = _siteName;
    _removeMetaTag('og:title');
    _removeMetaTag('og:description');
    _removeMetaTag('og:image');
    _removeMetaTag('og:url');
    _removeMetaTag('twitter:title');
    _removeMetaTag('twitter:description');
    _removeMetaTag('twitter:image');
    _removeLinkTag('canonical');
    _setMetaTag('robots', 'noindex, nofollow');
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
    if (plan.description.isNotEmpty) {
      return plan.description.length > 155
          ? '${plan.description.substring(0, 152)}...'
          : plan.description;
    }
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
    _removeStructuredData();
    final structuredData = <String, dynamic>{
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': plan.name,
      'description': plan.description.isNotEmpty
          ? plan.description
          : _generateDescription(plan),
      'image': plan.heroImageUrl,
      'brand': {'@type': 'Brand', 'name': _siteName},
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
    if (plan.locations.isNotEmpty) {
      structuredData['areaServed'] = plan.locations.map((l) {
        final m = <String, dynamic>{'@type': 'City', 'name': l.shortName};
        if (l.latitude != null && l.longitude != null) {
          m['geo'] = {
            '@type': 'GeoCoordinates',
            'latitude': l.latitude,
            'longitude': l.longitude,
          };
        }
        return m;
      }).toList();
    }
    if (plan.activityCategory != null) {
      structuredData['category'] = _getActivityDisplayName(plan.activityCategory!);
    }
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
    html.document
        .querySelectorAll('script[type="application/ld+json"]')
        .forEach((element) => element.remove());
  }
}
