// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'RSA';

  @override
  String get workspace => 'CARE WORKSPACE';

  @override
  String get overview => 'Overview';

  @override
  String get home => 'Home';

  @override
  String get chat => 'Chat';

  @override
  String get reportEvent => 'Report event';

  @override
  String get inbox => 'Inbox';

  @override
  String get more => 'More';

  @override
  String get wardDiary => 'Ward diary';

  @override
  String get shiftHandover => 'Shift handover';

  @override
  String get myShift => 'My shift';

  @override
  String get coordination => 'Coordination';

  @override
  String get management => 'Management';

  @override
  String get administration => 'Administration';

  @override
  String get demoData => 'Demo data';

  @override
  String get demoControls => 'Demo controls';

  @override
  String get demoPersona => 'Demo persona';

  @override
  String get online => 'Connected';

  @override
  String get offline => 'Offline';

  @override
  String get allCaughtUp => 'You\'re all caught up';

  @override
  String homeGreeting(Object name) {
    return 'Welcome back, $name.';
  }

  @override
  String get homeSubtitle =>
      'Your team, your ward. Everything you need for a connected shift.';

  @override
  String get morningShift => 'Morning shift';

  @override
  String get checkedIn => 'Checked in';

  @override
  String get offDuty => 'Off duty';

  @override
  String get checkOut => 'Check out';

  @override
  String get checkIn => 'Check in';

  @override
  String get assignedToYou => 'Assigned to you';

  @override
  String get unhandled => 'Unhandled';

  @override
  String get highPriority => 'High priority';

  @override
  String get onDutyNow => 'On duty now';

  @override
  String get needsAttention => 'Needs your attention';

  @override
  String get viewInbox => 'View inbox';

  @override
  String get attentionSubtitle => 'Keep the important things moving.';

  @override
  String get takeCharge => 'Take charge';

  @override
  String get yourTeam => 'On your shift';

  @override
  String get viewShift => 'View shift';

  @override
  String get assistantTitle => 'A little help, when you need it.';

  @override
  String get assistantCardText =>
      'Find a report, catch up on your ward, or prepare your shift summary.';

  @override
  String get openAssistant => 'Open RSA Assistant';

  @override
  String get diaryShortcutText => 'One shared timeline. Nothing left behind.';

  @override
  String get demoFooter =>
      'Demo workspace · Fictional people and synthetic care records.';

  @override
  String get moreSubtitle => 'Your ward tools, in one place.';

  @override
  String get documentReview => 'Document review';

  @override
  String get openWorkspace => 'Open workspace';

  @override
  String get shiftHours => '07:00–14:00 · Europe/Rome';

  @override
  String get attendanceHint =>
      'Your attendance and availability determine whether you can receive operational alerts.';

  @override
  String get teamCoverage => 'Team coverage';

  @override
  String versionLabel(Object number) {
    return 'Version $number';
  }

  @override
  String reviewedBy(Object name) {
    return 'Reviewed by $name';
  }

  @override
  String validatedBy(Object name) {
    return 'Clinically validated by $name';
  }

  @override
  String get importantEvents => 'Important reported events';

  @override
  String get handoverEvidenceHint =>
      'AI-organized draft from recorded sources. Review all items before signing.';

  @override
  String get noSources => 'No recorded source events';

  @override
  String get openFollowUps => 'Open follow-ups & unresolved notifications';

  @override
  String get staffContributions => 'Staff contributions';

  @override
  String get versionHistory => 'Version history';

  @override
  String get personalShiftSummary => 'Your shift summary';

  @override
  String get addContribution => 'Add contribution';

  @override
  String get markReviewed => 'Mark as reviewed';

  @override
  String get clinicalValidation => 'Validate clinical content';

  @override
  String get signOutgoing => 'Sign outgoing handover';

  @override
  String get acknowledgeHandover => 'Acknowledge signed version';

  @override
  String signedBy(Object name, Object time) {
    return 'Signed by $name at $time';
  }

  @override
  String get acknowledgements => 'Incoming acknowledgements';

  @override
  String get awaitingAcknowledgement => 'Awaiting acknowledgement';

  @override
  String get amendHandover => 'Amend handover';

  @override
  String get amendmentText => 'Amendment note';

  @override
  String get addAmendment => 'Add amendment';

  @override
  String get demoSignatureNote =>
      'Demo signatures record a workflow action; they are not qualified digital signatures.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get ocrSubtitle =>
      'Review extracted content while keeping the original.';

  @override
  String get needsReview => 'Needs review';

  @override
  String get reviewed => 'Reviewed';

  @override
  String get syntheticDocument => 'Synthetic document · original extraction';

  @override
  String get uncertainValue =>
      'Uncertain value: verify the room number against the original.';

  @override
  String get extractedText => 'Extracted text for review';

  @override
  String get confirmExtracted => 'Confirm extracted text';

  @override
  String get ocrValidationNote =>
      'Confirming extracted text does not validate clinical content.';

  @override
  String get wardOverview => 'Ward overview';

  @override
  String get unhandledNotifications => 'Unhandled notifications';

  @override
  String get reviewOperationalItems =>
      'Review priority, responsibility, and escalation.';

  @override
  String get presentStaffSkills => 'Staff, availability & skills';

  @override
  String get handoverCompletion => 'Handover completion';

  @override
  String get operationsOverview => 'Operations overview';

  @override
  String get aggregateOnly =>
      'Aggregate operational data within your assigned scope.';

  @override
  String get wardScope => 'Authorized ward scope';

  @override
  String get aggregateScope =>
      'Aggregate reports only · no resident records or conversations';

  @override
  String get technicalConsole =>
      'Accounts, integrations, and operational metadata.';

  @override
  String get accountsAssignments => 'Accounts & ward-role assignments';

  @override
  String get editAssignment => 'Edit assignment';

  @override
  String get integrations => 'Integration status';

  @override
  String get corporateSso => 'Corporate SSO / MFA';

  @override
  String get backendApi => 'FastAPI backend';

  @override
  String get remotePush => 'Remote push notifications';

  @override
  String get langGraph => 'LangGraph orchestration';

  @override
  String get notConnected => 'Not connected';

  @override
  String get routingRules => 'Routing policy · read-only';

  @override
  String get highRouting =>
      'High · on-duty nurse + present coordinator; escalate if unhandled.';

  @override
  String get mediumRouting =>
      'Medium · on-duty nurse quietly; remind, then escalate to coordinator.';

  @override
  String get lowRouting => 'Low · diary and handover only; no targeted alert.';

  @override
  String get auditMetadata => 'Restricted audit metadata';

  @override
  String get demoControlsSubtitle =>
      'Synthetic accounts and utilities for exploring this prototype.';

  @override
  String get demoConnectivity => 'Simulate connectivity';

  @override
  String get advanceTime => 'Advance time by 10 minutes';

  @override
  String get resetDemo => 'Reset demo data';

  @override
  String get resetDemoWarning =>
      'This replaces only this prototype\'s synthetic records. Your current demo changes will be lost.';

  @override
  String get demoTimingNote =>
      'Demo assumptions: High timeout 2 minutes; Medium reminder 5 minutes, escalation 10 minutes. These are not approved clinical policy.';

  @override
  String get storageScopeNote =>
      'Synthetic data is stored locally on this device/browser. Use one writing tab. No backend or cross-device messaging is connected.';

  @override
  String get currentWorkspace => 'Current workspace';

  @override
  String get openDemoControls => 'Open demo controls';

  @override
  String get reportShortcut => 'New event';

  @override
  String get facilityTimeZone => 'Facility time · Europe/Rome';

  @override
  String get helpNote => 'A connected shift. A shared picture.';

  @override
  String get accessDenied => 'Access denied';

  @override
  String get accessDeniedMessage =>
      'This account does not have permission to open this workspace.';

  @override
  String get storageErrorTitle => 'Local storage could not be opened';

  @override
  String get storageErrorMessage =>
      'Your data has not been replaced with an unsaved session. Check browser storage permissions, then retry.';

  @override
  String get retry => 'Retry';

  @override
  String get events => 'Reported events';

  @override
  String get open => 'Open events';

  @override
  String get high => 'High-priority events';

  @override
  String get onDuty => 'Staff on duty';

  @override
  String get staff => 'Staff accounts';

  @override
  String get wards => 'Authorized wards';

  @override
  String get closed => 'Closed events';

  @override
  String get queued => 'Queued events';

  @override
  String get total => 'Total events';

  @override
  String get totalEvents => 'Reported events';

  @override
  String get openEvents => 'Open events';

  @override
  String get highPriorityEvents => 'High-priority events';

  @override
  String get staffOnDuty => 'Staff on duty';

  @override
  String get pendingHandover => 'Pending handovers';

  @override
  String get rsaAssistant => 'RSA Assistant';

  @override
  String get demoPersonaShort => 'Switch demo persona';

  @override
  String get notifications => 'Notifications';

  @override
  String get navigation => 'Main navigation';

  @override
  String get today => 'Today';

  @override
  String get teamChat => 'Team chat';

  @override
  String get important => 'Important';

  @override
  String get voiceNote => 'Voice note';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get retryCapture => 'Try again';

  @override
  String get cameraUnavailable =>
      'Camera unavailable. Check browser permissions and device access, then retry.';

  @override
  String get microphoneUnavailable =>
      'Microphone unavailable. Check permissions and device access, then retry.';

  @override
  String get cameraInterrupted =>
      'Camera paused when the app was interrupted. Try again to reopen it.';

  @override
  String get captureFailed =>
      'The photo could not be captured. Try again; nothing has been attached.';

  @override
  String get recordingFailed =>
      'Recording failed. Nothing has been attached. Please retry.';

  @override
  String get capturePhoto => 'Capture photo';

  @override
  String get recordingHint => 'Ready to record · up to 2 minutes';

  @override
  String get startRecording => 'Start recording';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get reviewedTranscript => 'Optional reviewed transcript';

  @override
  String get transcriptHint =>
      'Type and review your transcript before attaching the voice note.';

  @override
  String get useSamplePhoto => 'Use synthetic photo sample';

  @override
  String get useSampleAudio => 'Use synthetic audio sample';

  @override
  String get cancelMedia => 'Cancel';

  @override
  String get retakePhoto => 'Retake';

  @override
  String get discardRecording => 'Discard recording';

  @override
  String get attachMedia => 'Attach';

  @override
  String get syntheticMedia => 'Sample attachment';

  @override
  String get attachedPhoto => 'Attached event photo';

  @override
  String get playAudio => 'Play audio';

  @override
  String get pauseAudio => 'Pause audio';

  @override
  String get playbackFailed =>
      'Playback unavailable. Retry in a supported browser or device.';

  @override
  String get removeAttachment => 'Remove attachment';

  @override
  String get chatTitle => 'Conversations';

  @override
  String get chatSubtitle => 'The right conversation, in one place.';

  @override
  String get searchConversations => 'Search conversations and messages';

  @override
  String get noConversations => 'No matching conversations';

  @override
  String get attachmentMessage => 'Attachment';

  @override
  String get assistantIntroShort => 'Your private, source-linked workspace';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get conversationUnavailable => 'Conversation unavailable';

  @override
  String get conversationDenied =>
      'This conversation is outside your current permissions.';

  @override
  String get chooseConversation => 'Choose a conversation';

  @override
  String get backToConversations => 'Back to conversations';

  @override
  String get privateAssistant => 'AI · Private to you · Current ward only';

  @override
  String get directConversation => 'Direct message · Shared ward';

  @override
  String get wardConversation => 'Ward workspace · Authorized members';

  @override
  String get searchHistory => 'Search this conversation';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get notTakenCharge => 'Not taken charge';

  @override
  String get viewLinkedEvent => 'View linked event';

  @override
  String get startConversation => 'Start the conversation';

  @override
  String get noMessagesFound => 'No messages found';

  @override
  String get conversationIntro =>
      'Messages stay in this authorized conversation.';

  @override
  String get changeSearch => 'Try another search term.';

  @override
  String get systemMessage => 'System';

  @override
  String get aiLabel => 'AI';

  @override
  String get sourcesLabel => 'Sources';

  @override
  String get replyMessage => 'Reply to message';

  @override
  String get createEventFromMessage => 'Create event from this message';

  @override
  String get replyingTo => 'Replying to:';

  @override
  String get cancelReply => 'Cancel reply';

  @override
  String get askAssistantHint => 'Ask about your ward…';

  @override
  String get messageTeamHint => 'Write a message…';

  @override
  String get sendMessage => 'Send message';

  @override
  String get assistantBoundary =>
      'Uses records you are authorized to access. No clinical advice or automatic actions.';

  @override
  String get suggestUnresolved => 'Show unresolved events in my ward.';

  @override
  String get suggestSummary => 'Summarize the last shift.';

  @override
  String get suggestDraft => 'Draft my shift summary.';

  @override
  String get suggestResident => 'Find today’s reports for resident R-014.';

  @override
  String get assistantWelcome => 'A little support for your shift.';

  @override
  String get assistantWelcomeBody =>
      'Find recorded events, follow open items, or prepare a source-linked summary. This conversation is private to you.';

  @override
  String get reportEventTitle => 'Report an event';

  @override
  String get reportEventSubtitle =>
      'A quick report keeps the right people informed.';

  @override
  String get eventDetails => 'Event details';

  @override
  String get eventTypeLabel => 'What happened?';

  @override
  String get eventTimeLabel => 'Event time';

  @override
  String get eventTimeHelp => 'Captured when this report was opened.';

  @override
  String get editEventTime => 'Edit event time';

  @override
  String get typeFall => 'Fall';

  @override
  String get typeHealth => 'Health';

  @override
  String get typeWandering => 'Wandering';

  @override
  String get typeAgitation => 'Agitation';

  @override
  String get typeRefusal => 'Refusal';

  @override
  String get typeSkinWound => 'Skin / wound';

  @override
  String get typeSafety => 'Safety';

  @override
  String get typeHygiene => 'Hygiene';

  @override
  String get priorityLabel => 'Priority';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityLow => 'Low';

  @override
  String get residentLabel => 'Resident';

  @override
  String get residentSearch => 'Search residents or room';

  @override
  String get residentOther => 'Other subject';

  @override
  String get residentOtherHelp => 'Visitor, staff, equipment or environment';

  @override
  String get selectResident => 'Select a resident';

  @override
  String get subjectLabel => 'Subject';

  @override
  String get subjectHint => 'Who or what is involved?';

  @override
  String get placeLabel => 'Place';

  @override
  String get placeRoom => 'Room';

  @override
  String get placeBathroom => 'Bathroom';

  @override
  String get placeCorridor => 'Corridor';

  @override
  String get placeDining => 'Dining room';

  @override
  String get placeOther => 'Other';

  @override
  String get placeHint => 'Add a place';

  @override
  String get notesLabel => 'Notes and attachments';

  @override
  String get optionalLabel => 'Optional';

  @override
  String get notesHint => 'Add a short, factual description…';

  @override
  String get reportRoutingHelp =>
      'The event will be added to the diary and handover. Notifications follow its priority.';

  @override
  String get sendEvent => 'Send event';

  @override
  String get sendingEvent => 'Sending…';

  @override
  String get reportSaved => 'Draft saved';

  @override
  String get reportNotSaved => 'Draft could not be saved';

  @override
  String get reportSent => 'Event sent';

  @override
  String get reportSentSubtitle =>
      'Your report is recorded in the ward diary and handover sources.';

  @override
  String get reportQueued => 'Queued offline';

  @override
  String get reportQueuedHelp =>
      'Staff have not been notified. Use your ward’s urgent communication procedure.';

  @override
  String get reportLowHelp =>
      'Added to the diary and handover. No priority alert was sent.';

  @override
  String get reportNoRecipients =>
      'No eligible staff are available. The event remains visibly unhandled.';

  @override
  String get viewEvent => 'View event';

  @override
  String get openConversation => 'Open conversation';

  @override
  String get backToWorkspace => 'Back to workspace';

  @override
  String get discardDraftTitle => 'Leave this report?';

  @override
  String get discardDraftBody =>
      'Your draft is saved. You can resume it when you return.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get leaveWithDraft => 'Save and leave';

  @override
  String get discardDraft => 'Discard draft';

  @override
  String get missingResident => 'Choose a resident or enter another subject.';

  @override
  String get inboxTitle => 'Priority inbox';

  @override
  String get inboxSubtitle => 'A clear view of the events that need attention.';

  @override
  String get filterMyItems => 'My items';

  @override
  String get filterWard => 'Ward';

  @override
  String get filterUnhandled => 'Unhandled';

  @override
  String get filterClosed => 'Closed';

  @override
  String get inboxEmpty => 'You’re up to date';

  @override
  String get inboxEmptyHelp => 'No notifications match this view.';

  @override
  String get diaryTitle => 'Ward diary';

  @override
  String get diarySubtitle => 'One shared record, from report to handover.';

  @override
  String get searchDiary => 'Search residents, events or notes';

  @override
  String get filterAll => 'All';

  @override
  String get filterDate => 'Date';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noDiaryEntries => 'No entries found';

  @override
  String get noDiaryEntriesHelp => 'Try another search or clear the filters.';

  @override
  String get eventTitle => 'Event report';

  @override
  String get eventMissing => 'Event unavailable';

  @override
  String get eventMissingHelp =>
      'This report is outside your access or no longer available.';

  @override
  String get eventReference => 'Reference';

  @override
  String get occurredAt => 'Occurred';

  @override
  String get registeredAt => 'Registered';

  @override
  String get synchronizedAt => 'Synchronized';

  @override
  String get reportedBy => 'Reported by';

  @override
  String get responsibility => 'Responsibility';

  @override
  String get takenCharge => 'Taken charge';

  @override
  String get closedLabel => 'Closed';

  @override
  String get queuedLabel => 'Queued offline';

  @override
  String get closeEvent => 'Close event';

  @override
  String get closeEventTitle => 'Close this event';

  @override
  String get outcomeLabel => 'Outcome note';

  @override
  String get outcomeHint => 'Record what happened and the outcome.';

  @override
  String get outcomeRequired => 'Add an outcome note before closing.';

  @override
  String get closeEventAction => 'Save outcome and close';

  @override
  String get eventClosed => 'Event closed';

  @override
  String get eventClaimed => 'You have taken charge of this event.';

  @override
  String eventClaimedBy(Object name) {
    return 'Taken charge by $name';
  }

  @override
  String eventClosedBy(Object name) {
    return 'Closed by $name';
  }

  @override
  String eventAuthorAt(Object name, Object time) {
    return '$name · $time';
  }

  @override
  String get routingTitle => 'Sources and activity';

  @override
  String get routingRecipients => 'Recipients selected';

  @override
  String get routingNone => 'No targeted notification';

  @override
  String get routingPending => 'Waiting for synchronization';

  @override
  String escalationLabel(Object level) {
    return 'Escalation level $level';
  }

  @override
  String get readingDoesNotClaim =>
      'Reading this report does not take responsibility. Use Take charge explicitly.';

  @override
  String get linkedRecords => 'Linked records';

  @override
  String get openDiary => 'Open diary';

  @override
  String get openHandover => 'Open handover';

  @override
  String get eventThread => 'Event conversation';

  @override
  String get originalMessage => 'Original message';

  @override
  String get amendEvent => 'Add correction';

  @override
  String get amendEventTitle => 'Add a tracked correction';

  @override
  String get correctionLabel => 'Correction';

  @override
  String get correctionHint =>
      'Describe the correction. The original report is preserved.';

  @override
  String get saveCorrection => 'Save correction';

  @override
  String get correctionRequired => 'Add the correction text.';

  @override
  String get correctionSaved => 'Correction added to history.';

  @override
  String get originalReport => 'Original report';

  @override
  String get correctionEntry => 'Correction';

  @override
  String get reportAmendmentHelp =>
      'Corrections are appended to the original; reports are never silently overwritten.';

  @override
  String get saveLabel => 'Save';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get doneLabel => 'Done';

  @override
  String get allResidents => 'All residents';

  @override
  String get allTypes => 'All event types';

  @override
  String get allPriorities => 'All priorities';

  @override
  String get allStatuses => 'All statuses';

  @override
  String eventCountLabel(Object count) {
    return '$count events';
  }

  @override
  String get fromMessageLabel =>
      'Prefilled from a message. Review the details before sending.';

  @override
  String get draftResumed => 'Saved draft restored';

  @override
  String get priorityChangedLabel => 'Priority changed from the type default';

  @override
  String get eventTimeChangedLabel => 'Event time was corrected before sending';

  @override
  String get lowPriorityNote => 'Diary and handover only';

  @override
  String get mediumPriorityNote => 'Quiet notification to the nurse on duty';

  @override
  String get highPriorityNote =>
      'Immediate notification to eligible on-duty staff';

  @override
  String get manageAttendance => 'Manage attendance and skills';

  @override
  String get presentOnShift => 'Present on shift';

  @override
  String get staffSkills => 'Skills (comma-separated)';

  @override
  String get allWards => 'All assigned wards';

  @override
  String get allDates => 'All dates';

  @override
  String get clearDateFilter => 'Clear date filter';

  @override
  String get savingDraft => 'Saving draft…';

  @override
  String get accountSettings => 'Account settings';

  @override
  String get accountSubtitle => 'Your profile and assigned ward context.';

  @override
  String get professionalRole => 'Professional role';

  @override
  String get assignedWards => 'Assigned wards';

  @override
  String get accountTimeZone => 'Facility time zone';

  @override
  String get currentWard => 'Current ward';

  @override
  String get developmentTools => 'Development tools';

  @override
  String get checkedOut => 'Checked out';

  @override
  String shiftCardSchedule(Object end, Object shift, Object start) {
    return '$shift shift  ·  $start–$end';
  }

  @override
  String get availabilityavailable => 'Available';

  @override
  String get availabilitybusy => 'Busy';

  @override
  String get availabilityonBreak => 'On break';

  @override
  String get documentOriginal => 'Original document · extracted text';

  @override
  String get clinicalWorkspace => 'Clinical review';
}
