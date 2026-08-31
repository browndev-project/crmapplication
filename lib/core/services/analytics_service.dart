import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for Firebase Analytics event logging, user tracking,
/// session engagement, and screen performance metrics across Trevion CRM.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Returns the FirebaseAnalyticsObserver to attach to MaterialApp.navigatorObservers
  /// for automatic screen navigation, engagement time per session, and country tracking.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Enable or disable analytics data collection
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting collection state: $e');
    }
  }

  /// Sets the unique user identifier for Firebase Analytics session reports
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      debugPrint('[AnalyticsService] Set user ID: $userId');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting user ID: $e');
    }
  }

  /// Sets user properties (e.g. systemRole, companyId, accountType)
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      debugPrint('[AnalyticsService] Set user property: $name = $value');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting user property $name: $e');
    }
  }

  /// Logs app open event
  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging app open: $e');
    }
  }

  /// Logs user login event with authentication method and user details
  Future<void> logLogin({
    required String loginMethod,
    String? role,
    String? companyId,
  }) async {
    try {
      await _analytics.logLogin(loginMethod: loginMethod);
      if (role != null) {
        await setUserProperty(name: 'user_role', value: role);
      }
      if (companyId != null) {
        await setUserProperty(name: 'company_id', value: companyId);
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging login: $e');
    }
  }

  /// Logs user signup event
  Future<void> logSignUp({required String signUpMethod, String? role}) async {
    try {
      await _analytics.logSignUp(signUpMethod: signUpMethod);
      if (role != null) {
        await setUserProperty(name: 'user_role', value: role);
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging sign up: $e');
    }
  }

  /// Logs user logout event and clears user ID
  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: 'user_logout');
      await setUserId(null);
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging logout: $e');
    }
  }

  /// Manually logs custom screen view event
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('[AnalyticsService] Logged screen view: $screenName');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging screen view: $e');
    }
  }

  /// Logs lead creation event
  Future<void> logLeadCreated({
    required String leadId,
    String? source,
    String? status,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'lead_created',
        parameters: {
          'lead_id': leadId,
          'lead_source': source ?? 'manual',
          'lead_status': status ?? 'New',
        },
      );
      debugPrint('[AnalyticsService] Logged lead_created: $leadId');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging lead_created: $e');
    }
  }

  /// Logs lead pipeline/status update event
  Future<void> logLeadStatusUpdated({
    required String leadId,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'lead_status_updated',
        parameters: {
          'lead_id': leadId,
          'old_status': oldStatus,
          'new_status': newStatus,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging lead_status_updated: $e');
    }
  }

  /// Logs call initiation to a lead
  Future<void> logLeadCallInitiated({
    required String leadId,
    String? callType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'lead_call_initiated',
        parameters: {
          'lead_id': leadId,
          'call_type': callType ?? 'outbound',
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging lead_call_initiated: $e');
    }
  }

  /// Logs call recording extraction and cloud upload
  Future<void> logCallRecordingUploaded({
    required double durationSeconds,
    required String uploadStatus,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'call_recording_uploaded',
        parameters: {
          'duration_seconds': durationSeconds,
          'upload_status': uploadStatus,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging call_recording_uploaded: $e');
    }
  }

  /// Logs property creation event
  Future<void> logPropertyCreated({
    required String propertyId,
    String? category,
    String? propertyType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'property_created',
        parameters: {
          'property_id': propertyId,
          'category': category ?? 'general',
          'property_type': propertyType ?? 'residential',
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging property_created: $e');
    }
  }

  /// Logs property search & filter application
  Future<void> logPropertyFiltered({
    required String category,
    String? status,
    String? propertyType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'property_filtered',
        parameters: {
          'category': category,
          'status': status ?? 'all',
          'property_type': propertyType ?? 'all',
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging property_filtered: $e');
    }
  }

  /// Logs invoice creation event
  Future<void> logInvoiceCreated({
    required String invoiceId,
    required double amount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'invoice_created',
        parameters: {
          'invoice_id': invoiceId,
          'value': amount,
          'currency': 'INR',
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging invoice_created: $e');
    }
  }

  /// Logs booking creation event
  Future<void> logBookingCreated({
    required String bookingId,
    required double amount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'booking_created',
        parameters: {
          'booking_id': bookingId,
          'value': amount,
          'currency': 'INR',
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging booking_created: $e');
    }
  }

  /// Logs quotation creation event
  Future<void> logQuotationCreated({
    required String quotationId,
    required double amount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'quotation_created',
        parameters: {
          'quotation_id': quotationId,
          'value': amount,
          'currency': 'INR',
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging quotation_created: $e');
    }
  }

  /// Logs WhatsApp campaign creation
  Future<void> logWhatsAppCampaignCreated({
    required String campaignId,
    required String campaignType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'whatsapp_campaign_created',
        parameters: {
          'campaign_id': campaignId,
          'campaign_type': campaignType,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging whatsapp_campaign_created: $e');
    }
  }

  /// Generic custom event logger
  Future<void> logCustomEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging custom event $name: $e');
    }
  }
}
