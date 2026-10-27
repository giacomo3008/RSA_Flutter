import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'RSA'**
  String get appName;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'CARE WORKSPACE'**
  String get workspace;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @reportEvent.
  ///
  /// In en, this message translates to:
  /// **'Report event'**
  String get reportEvent;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @wardDiary.
  ///
  /// In en, this message translates to:
  /// **'Ward diary'**
  String get wardDiary;

  /// No description provided for @shiftHandover.
  ///
  /// In en, this message translates to:
  /// **'Shift handover'**
  String get shiftHandover;

  /// No description provided for @myShift.
  ///
  /// In en, this message translates to:
  /// **'My shift'**
  String get myShift;

  /// No description provided for @coordination.
  ///
  /// In en, this message translates to:
  /// **'Coordination'**
  String get coordination;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// No description provided for @administration.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get administration;

  /// No description provided for @demoData.
  ///
  /// In en, this message translates to:
  /// **'Demo data'**
  String get demoData;

  /// No description provided for @demoControls.
  ///
  /// In en, this message translates to:
  /// **'Demo controls'**
  String get demoControls;

  /// No description provided for @demoPersona.
  ///
  /// In en, this message translates to:
  /// **'Demo persona'**
  String get demoPersona;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get allCaughtUp;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}.'**
  String homeGreeting(Object name);

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your team, your ward. Everything you need for a connected shift.'**
  String get homeSubtitle;

  /// No description provided for @morningShift.
  ///
  /// In en, this message translates to:
  /// **'Morning shift'**
  String get morningShift;

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkedIn;

  /// No description provided for @offDuty.
  ///
  /// In en, this message translates to:
  /// **'Off duty'**
  String get offDuty;

  /// No description provided for @checkOut.
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get checkOut;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkIn;

  /// No description provided for @assignedToYou.
  ///
  /// In en, this message translates to:
  /// **'Assigned to you'**
  String get assignedToYou;

  /// No description provided for @unhandled.
  ///
  /// In en, this message translates to:
  /// **'Unhandled'**
  String get unhandled;

  /// No description provided for @highPriority.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get highPriority;

  /// No description provided for @onDutyNow.
  ///
  /// In en, this message translates to:
  /// **'On duty now'**
  String get onDutyNow;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs your attention'**
  String get needsAttention;

  /// No description provided for @viewInbox.
  ///
  /// In en, this message translates to:
  /// **'View inbox'**
  String get viewInbox;

  /// No description provided for @attentionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the important things moving.'**
  String get attentionSubtitle;

  /// No description provided for @takeCharge.
  ///
  /// In en, this message translates to:
  /// **'Take charge'**
  String get takeCharge;

  /// No description provided for @yourTeam.
  ///
  /// In en, this message translates to:
  /// **'On your shift'**
  String get yourTeam;

  /// No description provided for @viewShift.
  ///
  /// In en, this message translates to:
  /// **'View shift'**
  String get viewShift;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'A little help, when you need it.'**
  String get assistantTitle;

  /// No description provided for @assistantCardText.
  ///
  /// In en, this message translates to:
  /// **'Find a report, catch up on your ward, or prepare your shift summary.'**
  String get assistantCardText;

  /// No description provided for @openAssistant.
  ///
  /// In en, this message translates to:
  /// **'Open RSA Assistant'**
  String get openAssistant;

  /// No description provided for @diaryShortcutText.
  ///
  /// In en, this message translates to:
  /// **'One shared timeline. Nothing left behind.'**
  String get diaryShortcutText;

  /// No description provided for @demoFooter.
  ///
  /// In en, this message translates to:
  /// **'Demo workspace · Fictional people and synthetic care records.'**
  String get demoFooter;

  /// No description provided for @moreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your ward tools, in one place.'**
  String get moreSubtitle;

  /// No description provided for @documentReview.
  ///
  /// In en, this message translates to:
  /// **'Document review'**
  String get documentReview;

  /// No description provided for @openWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open workspace'**
  String get openWorkspace;

  /// No description provided for @shiftHours.
  ///
  /// In en, this message translates to:
  /// **'07:00–14:00 · Europe/Rome'**
  String get shiftHours;

  /// No description provided for @attendanceHint.
  ///
  /// In en, this message translates to:
  /// **'Your attendance and availability determine whether you can receive operational alerts.'**
  String get attendanceHint;

  /// No description provided for @teamCoverage.
  ///
  /// In en, this message translates to:
  /// **'Team coverage'**
  String get teamCoverage;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {number}'**
  String versionLabel(Object number);

  /// No description provided for @reviewedBy.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by {name}'**
  String reviewedBy(Object name);

  /// No description provided for @validatedBy.
  ///
  /// In en, this message translates to:
  /// **'Clinically validated by {name}'**
  String validatedBy(Object name);

  /// No description provided for @importantEvents.
  ///
  /// In en, this message translates to:
  /// **'Important reported events'**
  String get importantEvents;

  /// No description provided for @handoverEvidenceHint.
  ///
  /// In en, this message translates to:
  /// **'AI-organized draft from recorded sources. Review all items before signing.'**
  String get handoverEvidenceHint;

  /// No description provided for @noSources.
  ///
  /// In en, this message translates to:
  /// **'No recorded source events'**
  String get noSources;

  /// No description provided for @openFollowUps.
  ///
  /// In en, this message translates to:
  /// **'Open follow-ups & unresolved notifications'**
  String get openFollowUps;

  /// No description provided for @staffContributions.
  ///
  /// In en, this message translates to:
  /// **'Staff contributions'**
  String get staffContributions;

  /// No description provided for @versionHistory.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get versionHistory;

  /// No description provided for @personalShiftSummary.
  ///
  /// In en, this message translates to:
  /// **'Your shift summary'**
  String get personalShiftSummary;

  /// No description provided for @addContribution.
  ///
  /// In en, this message translates to:
  /// **'Add contribution'**
  String get addContribution;

  /// No description provided for @markReviewed.
  ///
  /// In en, this message translates to:
  /// **'Mark as reviewed'**
  String get markReviewed;

  /// No description provided for @clinicalValidation.
  ///
  /// In en, this message translates to:
  /// **'Validate clinical content'**
  String get clinicalValidation;

  /// No description provided for @signOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Sign outgoing handover'**
  String get signOutgoing;

  /// No description provided for @acknowledgeHandover.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge signed version'**
  String get acknowledgeHandover;

  /// No description provided for @signedBy.
  ///
  /// In en, this message translates to:
  /// **'Signed by {name} at {time}'**
  String signedBy(Object name, Object time);

  /// No description provided for @acknowledgements.
  ///
  /// In en, this message translates to:
  /// **'Incoming acknowledgements'**
  String get acknowledgements;

  /// No description provided for @awaitingAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'Awaiting acknowledgement'**
  String get awaitingAcknowledgement;

  /// No description provided for @amendHandover.
  ///
  /// In en, this message translates to:
  /// **'Amend handover'**
  String get amendHandover;

  /// No description provided for @amendmentText.
  ///
  /// In en, this message translates to:
  /// **'Amendment note'**
  String get amendmentText;

  /// No description provided for @addAmendment.
  ///
  /// In en, this message translates to:
  /// **'Add amendment'**
  String get addAmendment;

  /// No description provided for @demoSignatureNote.
  ///
  /// In en, this message translates to:
  /// **'Demo signatures record a workflow action; they are not qualified digital signatures.'**
  String get demoSignatureNote;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ocrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review extracted content while keeping the original.'**
  String get ocrSubtitle;

  /// No description provided for @needsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get needsReview;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @syntheticDocument.
  ///
  /// In en, this message translates to:
  /// **'Synthetic document · original extraction'**
  String get syntheticDocument;

  /// No description provided for @uncertainValue.
  ///
  /// In en, this message translates to:
  /// **'Uncertain value: verify the room number against the original.'**
  String get uncertainValue;

  /// No description provided for @extractedText.
  ///
  /// In en, this message translates to:
  /// **'Extracted text for review'**
  String get extractedText;

  /// No description provided for @confirmExtracted.
  ///
  /// In en, this message translates to:
  /// **'Confirm extracted text'**
  String get confirmExtracted;

  /// No description provided for @ocrValidationNote.
  ///
  /// In en, this message translates to:
  /// **'Text review does not constitute physician clinical validation. OCR is simulated.'**
  String get ocrValidationNote;

  /// No description provided for @wardOverview.
  ///
  /// In en, this message translates to:
  /// **'Ward overview'**
  String get wardOverview;

  /// No description provided for @unhandledNotifications.
  ///
  /// In en, this message translates to:
  /// **'Unhandled notifications'**
  String get unhandledNotifications;

  /// No description provided for @reviewOperationalItems.
  ///
  /// In en, this message translates to:
  /// **'Review priority, responsibility, and escalation.'**
  String get reviewOperationalItems;

  /// No description provided for @presentStaffSkills.
  ///
  /// In en, this message translates to:
  /// **'Staff, availability & skills'**
  String get presentStaffSkills;

  /// No description provided for @handoverCompletion.
  ///
  /// In en, this message translates to:
  /// **'Handover completion'**
  String get handoverCompletion;

  /// No description provided for @operationsOverview.
  ///
  /// In en, this message translates to:
  /// **'Operations overview'**
  String get operationsOverview;

  /// No description provided for @aggregateOnly.
  ///
  /// In en, this message translates to:
  /// **'Aggregate operational data within your assigned scope.'**
  String get aggregateOnly;

  /// No description provided for @wardScope.
  ///
  /// In en, this message translates to:
  /// **'Authorized ward scope'**
  String get wardScope;

  /// No description provided for @aggregateScope.
  ///
  /// In en, this message translates to:
  /// **'Aggregate reports only · no resident records or conversations'**
  String get aggregateScope;

  /// No description provided for @technicalConsole.
  ///
  /// In en, this message translates to:
  /// **'Accounts, integrations, and operational metadata.'**
  String get technicalConsole;

  /// No description provided for @accountsAssignments.
  ///
  /// In en, this message translates to:
  /// **'Accounts & ward-role assignments'**
  String get accountsAssignments;

  /// No description provided for @editAssignment.
  ///
  /// In en, this message translates to:
  /// **'Edit assignment'**
  String get editAssignment;

  /// No description provided for @integrations.
  ///
  /// In en, this message translates to:
  /// **'Integration status'**
  String get integrations;

  /// No description provided for @corporateSso.
  ///
  /// In en, this message translates to:
  /// **'Corporate SSO / MFA'**
  String get corporateSso;

  /// No description provided for @backendApi.
  ///
  /// In en, this message translates to:
  /// **'FastAPI backend'**
  String get backendApi;

  /// No description provided for @remotePush.
  ///
  /// In en, this message translates to:
  /// **'Remote push notifications'**
  String get remotePush;

  /// No description provided for @langGraph.
  ///
  /// In en, this message translates to:
  /// **'LangGraph orchestration'**
  String get langGraph;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @routingRules.
  ///
  /// In en, this message translates to:
  /// **'Routing policy · read-only'**
  String get routingRules;

  /// No description provided for @highRouting.
  ///
  /// In en, this message translates to:
  /// **'High · on-duty nurse + present coordinator; escalate if unhandled.'**
  String get highRouting;

  /// No description provided for @mediumRouting.
  ///
  /// In en, this message translates to:
  /// **'Medium · on-duty nurse quietly; remind, then escalate to coordinator.'**
  String get mediumRouting;

  /// No description provided for @lowRouting.
  ///
  /// In en, this message translates to:
  /// **'Low · diary and handover only; no targeted alert.'**
  String get lowRouting;

  /// No description provided for @auditMetadata.
  ///
  /// In en, this message translates to:
  /// **'Restricted audit metadata'**
  String get auditMetadata;

  /// No description provided for @demoControlsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Synthetic accounts and utilities for exploring this prototype.'**
  String get demoControlsSubtitle;

  /// No description provided for @demoConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Simulate connectivity'**
  String get demoConnectivity;

  /// No description provided for @advanceTime.
  ///
  /// In en, this message translates to:
  /// **'Advance time by 10 minutes'**
  String get advanceTime;

  /// No description provided for @resetDemo.
  ///
  /// In en, this message translates to:
  /// **'Reset demo data'**
  String get resetDemo;

  /// No description provided for @resetDemoWarning.
  ///
  /// In en, this message translates to:
  /// **'This replaces only this prototype\'s synthetic records. Your current demo changes will be lost.'**
  String get resetDemoWarning;

  /// No description provided for @demoTimingNote.
  ///
  /// In en, this message translates to:
  /// **'Demo assumptions: High timeout 2 minutes; Medium reminder 5 minutes, escalation 10 minutes. These are not approved clinical policy.'**
  String get demoTimingNote;

  /// No description provided for @storageScopeNote.
  ///
  /// In en, this message translates to:
  /// **'Synthetic data is stored locally on this device/browser. Use one writing tab. No backend or cross-device messaging is connected.'**
  String get storageScopeNote;

  /// No description provided for @currentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Current workspace'**
  String get currentWorkspace;

  /// No description provided for @openDemoControls.
  ///
  /// In en, this message translates to:
  /// **'Open demo controls'**
  String get openDemoControls;

  /// No description provided for @reportShortcut.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get reportShortcut;

  /// No description provided for @facilityTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Facility time · Europe/Rome'**
  String get facilityTimeZone;

  /// No description provided for @helpNote.
  ///
  /// In en, this message translates to:
  /// **'A connected shift. A shared picture.'**
  String get helpNote;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get accessDenied;

  /// No description provided for @accessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'This account does not have permission to open this workspace.'**
  String get accessDeniedMessage;

  /// No description provided for @storageErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Local storage could not be opened'**
  String get storageErrorTitle;

  /// No description provided for @storageErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Your data has not been replaced with an unsaved session. Check browser storage permissions, then retry.'**
  String get storageErrorMessage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Reported events'**
  String get events;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open events'**
  String get open;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High-priority events'**
  String get high;

  /// No description provided for @onDuty.
  ///
  /// In en, this message translates to:
  /// **'Staff on duty'**
  String get onDuty;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'Staff accounts'**
  String get staff;

  /// No description provided for @wards.
  ///
  /// In en, this message translates to:
  /// **'Authorized wards'**
  String get wards;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed events'**
  String get closed;

  /// No description provided for @queued.
  ///
  /// In en, this message translates to:
  /// **'Queued events'**
  String get queued;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total events'**
  String get total;

  /// No description provided for @totalEvents.
  ///
  /// In en, this message translates to:
  /// **'Reported events'**
  String get totalEvents;

  /// No description provided for @openEvents.
  ///
  /// In en, this message translates to:
  /// **'Open events'**
  String get openEvents;

  /// No description provided for @highPriorityEvents.
  ///
  /// In en, this message translates to:
  /// **'High-priority events'**
  String get highPriorityEvents;

  /// No description provided for @staffOnDuty.
  ///
  /// In en, this message translates to:
  /// **'Staff on duty'**
  String get staffOnDuty;

  /// No description provided for @pendingHandover.
  ///
  /// In en, this message translates to:
  /// **'Pending handovers'**
  String get pendingHandover;

  /// No description provided for @rsaAssistant.
  ///
  /// In en, this message translates to:
  /// **'RSA Assistant'**
  String get rsaAssistant;

  /// No description provided for @demoPersonaShort.
  ///
  /// In en, this message translates to:
  /// **'Switch demo persona'**
  String get demoPersonaShort;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get navigation;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @teamChat.
  ///
  /// In en, this message translates to:
  /// **'Team chat'**
  String get teamChat;

  /// No description provided for @important.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get important;

  /// No description provided for @voiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceNote;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @retryCapture.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryCapture;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Check browser permissions and device access, or choose the synthetic sample.'**
  String get cameraUnavailable;

  /// No description provided for @microphoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Microphone unavailable. Check permissions and device access, or choose the synthetic sample.'**
  String get microphoneUnavailable;

  /// No description provided for @cameraInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Camera paused when the app was interrupted. Try again to reopen it.'**
  String get cameraInterrupted;

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be captured. Try again; nothing has been attached.'**
  String get captureFailed;

  /// No description provided for @recordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed. Nothing has been attached. You can retry or choose the synthetic sample.'**
  String get recordingFailed;

  /// No description provided for @capturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Capture photo'**
  String get capturePhoto;

  /// No description provided for @recordingHint.
  ///
  /// In en, this message translates to:
  /// **'Ready to record · up to 2 minutes'**
  String get recordingHint;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording;

  /// No description provided for @reviewedTranscript.
  ///
  /// In en, this message translates to:
  /// **'Optional reviewed transcript'**
  String get reviewedTranscript;

  /// No description provided for @transcriptHint.
  ///
  /// In en, this message translates to:
  /// **'Type and review your own transcript. Automatic transcription is not connected.'**
  String get transcriptHint;

  /// No description provided for @useSamplePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use synthetic photo sample'**
  String get useSamplePhoto;

  /// No description provided for @useSampleAudio.
  ///
  /// In en, this message translates to:
  /// **'Use synthetic audio sample'**
  String get useSampleAudio;

  /// No description provided for @cancelMedia.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelMedia;

  /// No description provided for @retakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retakePhoto;

  /// No description provided for @discardRecording.
  ///
  /// In en, this message translates to:
  /// **'Discard recording'**
  String get discardRecording;

  /// No description provided for @attachMedia.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachMedia;

  /// No description provided for @syntheticMedia.
  ///
  /// In en, this message translates to:
  /// **'Synthetic sample · demo only'**
  String get syntheticMedia;

  /// No description provided for @attachedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attached event photo'**
  String get attachedPhoto;

  /// No description provided for @playAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playAudio;

  /// No description provided for @pauseAudio.
  ///
  /// In en, this message translates to:
  /// **'Pause audio'**
  String get pauseAudio;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback unavailable. Retry in a supported browser or device.'**
  String get playbackFailed;

  /// No description provided for @removeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get removeAttachment;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Team chat'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The right conversation, in one place.'**
  String get chatSubtitle;

  /// No description provided for @searchConversations.
  ///
  /// In en, this message translates to:
  /// **'Search conversations and messages'**
  String get searchConversations;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations'**
  String get noConversations;

  /// No description provided for @attachmentMessage.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachmentMessage;

  /// No description provided for @assistantIntroShort.
  ///
  /// In en, this message translates to:
  /// **'Your private, source-linked workspace'**
  String get assistantIntroShort;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @conversationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Conversation unavailable'**
  String get conversationUnavailable;

  /// No description provided for @conversationDenied.
  ///
  /// In en, this message translates to:
  /// **'This conversation is outside your current permissions.'**
  String get conversationDenied;

  /// No description provided for @chooseConversation.
  ///
  /// In en, this message translates to:
  /// **'Choose a conversation'**
  String get chooseConversation;

  /// No description provided for @backToConversations.
  ///
  /// In en, this message translates to:
  /// **'Back to conversations'**
  String get backToConversations;

  /// No description provided for @privateAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI · Private to you · Current ward only'**
  String get privateAssistant;

  /// No description provided for @directConversation.
  ///
  /// In en, this message translates to:
  /// **'Direct message · Shared ward'**
  String get directConversation;

  /// No description provided for @wardConversation.
  ///
  /// In en, this message translates to:
  /// **'Ward workspace · Authorized members'**
  String get wardConversation;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search this conversation'**
  String get searchHistory;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @notTakenCharge.
  ///
  /// In en, this message translates to:
  /// **'Not taken charge'**
  String get notTakenCharge;

  /// No description provided for @viewLinkedEvent.
  ///
  /// In en, this message translates to:
  /// **'View linked event'**
  String get viewLinkedEvent;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation'**
  String get startConversation;

  /// No description provided for @noMessagesFound.
  ///
  /// In en, this message translates to:
  /// **'No messages found'**
  String get noMessagesFound;

  /// No description provided for @conversationIntro.
  ///
  /// In en, this message translates to:
  /// **'Messages stay in this authorized conversation.'**
  String get conversationIntro;

  /// No description provided for @changeSearch.
  ///
  /// In en, this message translates to:
  /// **'Try another search term.'**
  String get changeSearch;

  /// No description provided for @systemMessage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMessage;

  /// No description provided for @aiLabel.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiLabel;

  /// No description provided for @sourcesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesLabel;

  /// No description provided for @replyMessage.
  ///
  /// In en, this message translates to:
  /// **'Reply to message'**
  String get replyMessage;

  /// No description provided for @createEventFromMessage.
  ///
  /// In en, this message translates to:
  /// **'Create event from this message'**
  String get createEventFromMessage;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to:'**
  String get replyingTo;

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @askAssistantHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about your ward…'**
  String get askAssistantHint;

  /// No description provided for @messageTeamHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get messageTeamHint;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @assistantBoundary.
  ///
  /// In en, this message translates to:
  /// **'Uses current demo records. No clinical advice or automatic actions.'**
  String get assistantBoundary;

  /// No description provided for @suggestUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Show unresolved events in my ward.'**
  String get suggestUnresolved;

  /// No description provided for @suggestSummary.
  ///
  /// In en, this message translates to:
  /// **'Summarize the last shift.'**
  String get suggestSummary;

  /// No description provided for @suggestDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft my shift summary.'**
  String get suggestDraft;

  /// No description provided for @suggestResident.
  ///
  /// In en, this message translates to:
  /// **'Find today’s reports for resident R-014.'**
  String get suggestResident;

  /// No description provided for @assistantWelcome.
  ///
  /// In en, this message translates to:
  /// **'A little support for your shift.'**
  String get assistantWelcome;

  /// No description provided for @assistantWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Find recorded events, follow open items, or prepare a source-linked summary. This conversation is private to you.'**
  String get assistantWelcomeBody;

  /// No description provided for @reportEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Report an event'**
  String get reportEventTitle;

  /// No description provided for @reportEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick report keeps the right people informed.'**
  String get reportEventSubtitle;

  /// No description provided for @eventDetails.
  ///
  /// In en, this message translates to:
  /// **'Event details'**
  String get eventDetails;

  /// No description provided for @eventTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get eventTypeLabel;

  /// No description provided for @eventTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Event time'**
  String get eventTimeLabel;

  /// No description provided for @eventTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Captured when this report was opened.'**
  String get eventTimeHelp;

  /// No description provided for @editEventTime.
  ///
  /// In en, this message translates to:
  /// **'Edit event time'**
  String get editEventTime;

  /// No description provided for @typeFall.
  ///
  /// In en, this message translates to:
  /// **'Fall'**
  String get typeFall;

  /// No description provided for @typeHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get typeHealth;

  /// No description provided for @typeWandering.
  ///
  /// In en, this message translates to:
  /// **'Wandering'**
  String get typeWandering;

  /// No description provided for @typeAgitation.
  ///
  /// In en, this message translates to:
  /// **'Agitation'**
  String get typeAgitation;

  /// No description provided for @typeRefusal.
  ///
  /// In en, this message translates to:
  /// **'Refusal'**
  String get typeRefusal;

  /// No description provided for @typeSkinWound.
  ///
  /// In en, this message translates to:
  /// **'Skin / wound'**
  String get typeSkinWound;

  /// No description provided for @typeSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get typeSafety;

  /// No description provided for @typeHygiene.
  ///
  /// In en, this message translates to:
  /// **'Hygiene'**
  String get typeHygiene;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priorityLabel;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @residentLabel.
  ///
  /// In en, this message translates to:
  /// **'Resident'**
  String get residentLabel;

  /// No description provided for @residentSearch.
  ///
  /// In en, this message translates to:
  /// **'Search residents or room'**
  String get residentSearch;

  /// No description provided for @residentOther.
  ///
  /// In en, this message translates to:
  /// **'Other subject'**
  String get residentOther;

  /// No description provided for @residentOtherHelp.
  ///
  /// In en, this message translates to:
  /// **'Visitor, staff, equipment or environment'**
  String get residentOtherHelp;

  /// No description provided for @selectResident.
  ///
  /// In en, this message translates to:
  /// **'Select a resident'**
  String get selectResident;

  /// No description provided for @subjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subjectLabel;

  /// No description provided for @subjectHint.
  ///
  /// In en, this message translates to:
  /// **'Who or what is involved?'**
  String get subjectHint;

  /// No description provided for @placeLabel.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeLabel;

  /// No description provided for @placeRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get placeRoom;

  /// No description provided for @placeBathroom.
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get placeBathroom;

  /// No description provided for @placeCorridor.
  ///
  /// In en, this message translates to:
  /// **'Corridor'**
  String get placeCorridor;

  /// No description provided for @placeDining.
  ///
  /// In en, this message translates to:
  /// **'Dining room'**
  String get placeDining;

  /// No description provided for @placeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get placeOther;

  /// No description provided for @placeHint.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get placeHint;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes and attachments'**
  String get notesLabel;

  /// No description provided for @optionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalLabel;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short, factual description…'**
  String get notesHint;

  /// No description provided for @reportRoutingHelp.
  ///
  /// In en, this message translates to:
  /// **'The event will be added to the diary and handover. Notifications follow its priority.'**
  String get reportRoutingHelp;

  /// No description provided for @sendEvent.
  ///
  /// In en, this message translates to:
  /// **'Send event'**
  String get sendEvent;

  /// No description provided for @sendingEvent.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sendingEvent;

  /// No description provided for @reportSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get reportSaved;

  /// No description provided for @reportNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft could not be saved'**
  String get reportNotSaved;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Event sent'**
  String get reportSent;

  /// No description provided for @reportSentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your report is recorded in the ward diary and handover sources.'**
  String get reportSentSubtitle;

  /// No description provided for @reportQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued offline'**
  String get reportQueued;

  /// No description provided for @reportQueuedHelp.
  ///
  /// In en, this message translates to:
  /// **'Staff have not been notified. Use your ward’s urgent communication procedure.'**
  String get reportQueuedHelp;

  /// No description provided for @reportLowHelp.
  ///
  /// In en, this message translates to:
  /// **'Added to the diary and handover. No priority alert was sent.'**
  String get reportLowHelp;

  /// No description provided for @reportNoRecipients.
  ///
  /// In en, this message translates to:
  /// **'No eligible staff are available. The event remains visibly unhandled.'**
  String get reportNoRecipients;

  /// No description provided for @viewEvent.
  ///
  /// In en, this message translates to:
  /// **'View event'**
  String get viewEvent;

  /// No description provided for @openConversation.
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get openConversation;

  /// No description provided for @backToWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Back to workspace'**
  String get backToWorkspace;

  /// No description provided for @discardDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this report?'**
  String get discardDraftTitle;

  /// No description provided for @discardDraftBody.
  ///
  /// In en, this message translates to:
  /// **'Your draft is saved. You can resume it when you return.'**
  String get discardDraftBody;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @leaveWithDraft.
  ///
  /// In en, this message translates to:
  /// **'Save and leave'**
  String get leaveWithDraft;

  /// No description provided for @discardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get discardDraft;

  /// No description provided for @missingResident.
  ///
  /// In en, this message translates to:
  /// **'Choose a resident or enter another subject.'**
  String get missingResident;

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority inbox'**
  String get inboxTitle;

  /// No description provided for @inboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A clear view of the events that need attention.'**
  String get inboxSubtitle;

  /// No description provided for @filterMyItems.
  ///
  /// In en, this message translates to:
  /// **'My items'**
  String get filterMyItems;

  /// No description provided for @filterWard.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get filterWard;

  /// No description provided for @filterUnhandled.
  ///
  /// In en, this message translates to:
  /// **'Unhandled'**
  String get filterUnhandled;

  /// No description provided for @filterClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get filterClosed;

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'You’re up to date'**
  String get inboxEmpty;

  /// No description provided for @inboxEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'No notifications match this view.'**
  String get inboxEmptyHelp;

  /// No description provided for @diaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Ward diary'**
  String get diaryTitle;

  /// No description provided for @diarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'One shared record, from report to handover.'**
  String get diarySubtitle;

  /// No description provided for @searchDiary.
  ///
  /// In en, this message translates to:
  /// **'Search residents, events or notes'**
  String get searchDiary;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get filterDate;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noDiaryEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries found'**
  String get noDiaryEntries;

  /// No description provided for @noDiaryEntriesHelp.
  ///
  /// In en, this message translates to:
  /// **'Try another search or clear the filters.'**
  String get noDiaryEntriesHelp;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event report'**
  String get eventTitle;

  /// No description provided for @eventMissing.
  ///
  /// In en, this message translates to:
  /// **'Event unavailable'**
  String get eventMissing;

  /// No description provided for @eventMissingHelp.
  ///
  /// In en, this message translates to:
  /// **'This report is outside your access or no longer available.'**
  String get eventMissingHelp;

  /// No description provided for @eventReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get eventReference;

  /// No description provided for @occurredAt.
  ///
  /// In en, this message translates to:
  /// **'Occurred'**
  String get occurredAt;

  /// No description provided for @registeredAt.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get registeredAt;

  /// No description provided for @synchronizedAt.
  ///
  /// In en, this message translates to:
  /// **'Synchronized'**
  String get synchronizedAt;

  /// No description provided for @reportedBy.
  ///
  /// In en, this message translates to:
  /// **'Reported by'**
  String get reportedBy;

  /// No description provided for @responsibility.
  ///
  /// In en, this message translates to:
  /// **'Responsibility'**
  String get responsibility;

  /// No description provided for @takenCharge.
  ///
  /// In en, this message translates to:
  /// **'Taken charge'**
  String get takenCharge;

  /// No description provided for @closedLabel.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedLabel;

  /// No description provided for @queuedLabel.
  ///
  /// In en, this message translates to:
  /// **'Queued offline'**
  String get queuedLabel;

  /// No description provided for @closeEvent.
  ///
  /// In en, this message translates to:
  /// **'Close event'**
  String get closeEvent;

  /// No description provided for @closeEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Close this event'**
  String get closeEventTitle;

  /// No description provided for @outcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Outcome note'**
  String get outcomeLabel;

  /// No description provided for @outcomeHint.
  ///
  /// In en, this message translates to:
  /// **'Record what happened and the outcome.'**
  String get outcomeHint;

  /// No description provided for @outcomeRequired.
  ///
  /// In en, this message translates to:
  /// **'Add an outcome note before closing.'**
  String get outcomeRequired;

  /// No description provided for @closeEventAction.
  ///
  /// In en, this message translates to:
  /// **'Save outcome and close'**
  String get closeEventAction;

  /// No description provided for @eventClosed.
  ///
  /// In en, this message translates to:
  /// **'Event closed'**
  String get eventClosed;

  /// No description provided for @eventClaimed.
  ///
  /// In en, this message translates to:
  /// **'You have taken charge of this event.'**
  String get eventClaimed;

  /// No description provided for @eventClaimedBy.
  ///
  /// In en, this message translates to:
  /// **'Taken charge by {name}'**
  String eventClaimedBy(Object name);

  /// No description provided for @eventClosedBy.
  ///
  /// In en, this message translates to:
  /// **'Closed by {name}'**
  String eventClosedBy(Object name);

  /// No description provided for @eventAuthorAt.
  ///
  /// In en, this message translates to:
  /// **'{name} · {time}'**
  String eventAuthorAt(Object name, Object time);

  /// No description provided for @routingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources and activity'**
  String get routingTitle;

  /// No description provided for @routingRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients selected'**
  String get routingRecipients;

  /// No description provided for @routingNone.
  ///
  /// In en, this message translates to:
  /// **'No targeted notification'**
  String get routingNone;

  /// No description provided for @routingPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for synchronization'**
  String get routingPending;

  /// No description provided for @escalationLabel.
  ///
  /// In en, this message translates to:
  /// **'Escalation level {level}'**
  String escalationLabel(Object level);

  /// No description provided for @readingDoesNotClaim.
  ///
  /// In en, this message translates to:
  /// **'Reading this report does not take responsibility. Use Take charge explicitly.'**
  String get readingDoesNotClaim;

  /// No description provided for @linkedRecords.
  ///
  /// In en, this message translates to:
  /// **'Linked records'**
  String get linkedRecords;

  /// No description provided for @openDiary.
  ///
  /// In en, this message translates to:
  /// **'Open diary'**
  String get openDiary;

  /// No description provided for @openHandover.
  ///
  /// In en, this message translates to:
  /// **'Open handover'**
  String get openHandover;

  /// No description provided for @eventThread.
  ///
  /// In en, this message translates to:
  /// **'Event conversation'**
  String get eventThread;

  /// No description provided for @originalMessage.
  ///
  /// In en, this message translates to:
  /// **'Original message'**
  String get originalMessage;

  /// No description provided for @amendEvent.
  ///
  /// In en, this message translates to:
  /// **'Add correction'**
  String get amendEvent;

  /// No description provided for @amendEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a tracked correction'**
  String get amendEventTitle;

  /// No description provided for @correctionLabel.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get correctionLabel;

  /// No description provided for @correctionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the correction. The original report is preserved.'**
  String get correctionHint;

  /// No description provided for @saveCorrection.
  ///
  /// In en, this message translates to:
  /// **'Save correction'**
  String get saveCorrection;

  /// No description provided for @correctionRequired.
  ///
  /// In en, this message translates to:
  /// **'Add the correction text.'**
  String get correctionRequired;

  /// No description provided for @correctionSaved.
  ///
  /// In en, this message translates to:
  /// **'Correction added to history.'**
  String get correctionSaved;

  /// No description provided for @originalReport.
  ///
  /// In en, this message translates to:
  /// **'Original report'**
  String get originalReport;

  /// No description provided for @correctionEntry.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get correctionEntry;

  /// No description provided for @reportAmendmentHelp.
  ///
  /// In en, this message translates to:
  /// **'Corrections are appended to the original; reports are never silently overwritten.'**
  String get reportAmendmentHelp;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @cancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelLabel;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneLabel;

  /// No description provided for @allResidents.
  ///
  /// In en, this message translates to:
  /// **'All residents'**
  String get allResidents;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All event types'**
  String get allTypes;

  /// No description provided for @allPriorities.
  ///
  /// In en, this message translates to:
  /// **'All priorities'**
  String get allPriorities;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @eventCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String eventCountLabel(Object count);

  /// No description provided for @fromMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Prefilled from a message. Review the details before sending.'**
  String get fromMessageLabel;

  /// No description provided for @draftResumed.
  ///
  /// In en, this message translates to:
  /// **'Saved draft restored'**
  String get draftResumed;

  /// No description provided for @priorityChangedLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority changed from the type default'**
  String get priorityChangedLabel;

  /// No description provided for @eventTimeChangedLabel.
  ///
  /// In en, this message translates to:
  /// **'Event time was corrected before sending'**
  String get eventTimeChangedLabel;

  /// No description provided for @lowPriorityNote.
  ///
  /// In en, this message translates to:
  /// **'Diary and handover only'**
  String get lowPriorityNote;

  /// No description provided for @mediumPriorityNote.
  ///
  /// In en, this message translates to:
  /// **'Quiet notification to the nurse on duty'**
  String get mediumPriorityNote;

  /// No description provided for @highPriorityNote.
  ///
  /// In en, this message translates to:
  /// **'Immediate notification to eligible on-duty staff'**
  String get highPriorityNote;

  /// No description provided for @manageAttendance.
  ///
  /// In en, this message translates to:
  /// **'Manage attendance and skills'**
  String get manageAttendance;

  /// No description provided for @presentOnShift.
  ///
  /// In en, this message translates to:
  /// **'Present on shift'**
  String get presentOnShift;

  /// No description provided for @staffSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills (comma-separated)'**
  String get staffSkills;

  /// No description provided for @allWards.
  ///
  /// In en, this message translates to:
  /// **'All assigned wards'**
  String get allWards;

  /// No description provided for @allDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get allDates;

  /// No description provided for @clearDateFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear date filter'**
  String get clearDateFilter;

  /// No description provided for @savingDraft.
  ///
  /// In en, this message translates to:
  /// **'Saving draft…'**
  String get savingDraft;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
