import 'dart:convert';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Serializable domain records, independent of Flutter and storage row types.
enum Role {
  nurse,
  assistant,
  technician,
  physician,
  coordinator,
  management,
  administrator,
}

enum Capability {
  care,
  report,
  chat,
  diary,
  claim,
  clinicalValidation,
  coordination,
  signHandover,
  acknowledge,
  management,
  administration,
  audit,
}

enum Availability { available, busy, onBreak }

enum Priority { low, medium, high }

enum EventType {
  fall,
  health,
  wandering,
  agitation,
  refusal,
  skin,
  safety,
  hygiene,
}

enum EventStatus { unhandled, takenCharge, closed }

enum SyncStatus { sent, queued, failed }

enum HandoverStatus {
  aiDraft,
  reviewed,
  clinicallyValidated,
  signed,
  acknowledged,
}

enum ConversationKind { ward, direct, event, assistant }

const roleCapabilities = <Role, Set<Capability>>{
  Role.nurse: {
    Capability.care,
    Capability.report,
    Capability.chat,
    Capability.diary,
    Capability.claim,
    Capability.acknowledge,
  },
  Role.assistant: {
    Capability.care,
    Capability.report,
    Capability.chat,
    Capability.diary,
    Capability.acknowledge,
  },
  Role.technician: {
    Capability.care,
    Capability.report,
    Capability.chat,
    Capability.diary,
    Capability.acknowledge,
  },
  Role.physician: {
    Capability.care,
    Capability.report,
    Capability.chat,
    Capability.diary,
    Capability.clinicalValidation,
    Capability.acknowledge,
  },
  Role.coordinator: {
    Capability.care,
    Capability.report,
    Capability.chat,
    Capability.diary,
    Capability.claim,
    Capability.coordination,
    Capability.signHandover,
    Capability.acknowledge,
  },
  Role.management: {Capability.management},
  Role.administrator: {Capability.administration, Capability.audit},
};

extension RoleLabel on Role {
  String get label => switch (this) {
    Role.nurse => 'Nurse',
    Role.assistant => 'Healthcare assistant',
    Role.technician => 'Technician',
    Role.physician => 'Physician',
    Role.coordinator => 'Coordinator',
    Role.management => 'Medical management',
    Role.administrator => 'System administrator',
  };
}

extension EventTypeInfo on EventType {
  String get label => switch (this) {
    EventType.skin => 'Skin / wound',
    _ => '${name[0].toUpperCase()}${name.substring(1)}',
  };
  Priority get defaultPriority => switch (this) {
    EventType.fall || EventType.health || EventType.wandering => Priority.high,
    EventType.hygiene => Priority.low,
    _ => Priority.medium,
  };
}

extension PriorityLabel on Priority {
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

extension AvailabilityLabel on Availability {
  String get label => switch (this) {
    Availability.available => 'Available',
    Availability.busy => 'Busy',
    Availability.onBreak => 'On break',
  };
}

extension EventStatusLabel on EventStatus {
  String get label => switch (this) {
    EventStatus.unhandled => 'Not taken charge',
    EventStatus.takenCharge => 'Taken charge',
    EventStatus.closed => 'Closed',
  };
}

extension HandoverStatusLabel on HandoverStatus {
  String get label => switch (this) {
    HandoverStatus.aiDraft => 'AI draft',
    HandoverStatus.reviewed => 'Reviewed',
    HandoverStatus.clinicallyValidated => 'Clinical validation',
    HandoverStatus.signed => 'Signed by outgoing coordinator',
    HandoverStatus.acknowledged => 'Acknowledged by incoming staff',
  };
}

DateTime instant(Object? v) => DateTime.parse(v as String).toUtc();
List<String> strings(Object? v) => (v as List? ?? []).cast<String>();
Map<String, dynamic> objectMap(Object? v) =>
    Map<String, dynamic>.from(v as Map);

class Ward {
  final String id, name;
  const Ward(this.id, this.name);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Ward.fromJson(Map<String, dynamic> j) => Ward(j['id'], j['name']);
}

class WardRoleAssignment {
  final String wardId;
  final Role role;
  const WardRoleAssignment({required this.wardId, required this.role});
  Map<String, dynamic> toJson() => {'wardId': wardId, 'role': role.name};
  factory WardRoleAssignment.fromJson(Map<String, dynamic> j) =>
      WardRoleAssignment(
        wardId: j['wardId'],
        role: Role.values.byName(j['role']),
      );
}

class StaffMember {
  final String id, name;

  /// Primary presentation role. Authorization always uses explicit assignments.
  Role role;
  List<WardRoleAssignment> assignments;
  List<String> get wardIds => assignments.map((a) => a.wardId).toSet().toList();

  /// Legacy account editor replaces assignments with one selected role per ward.
  set wardIds(List<String> values) {
    assignments = values
        .map((id) => WardRoleAssignment(wardId: id, role: role))
        .toList();
  }

  List<String> skills;
  bool onDuty;
  Availability availability;
  DateTime? checkedInAt, checkedOutAt;
  StaffMember({
    required this.id,
    required this.name,
    required Role role,
    required List<String> wardIds,
    List<WardRoleAssignment>? assignments,
    this.onDuty = true,
    this.availability = Availability.available,
    List<String>? skills,
    this.checkedInAt,
    this.checkedOutAt,
  }) : role = role,
       assignments =
           assignments ??
           wardIds
               .map((id) => WardRoleAssignment(wardId: id, role: role))
               .toList(),
       skills = skills ?? ['General care'];
  String get initials => name.split(' ').map((s) => s[0]).take(2).join();
  bool hasRole(Role role, [String? wardId]) => assignments.any(
    (a) => a.role == role && (wardId == null || a.wardId == wardId),
  );

  /// Presentation follows the same ward scope as authorization.
  String rolesLabelForWard(String wardId) {
    final labels = assignments
        .where((assignment) => assignment.wardId == wardId)
        .map((assignment) => assignment.role.label)
        .toSet();
    return labels.isEmpty ? 'No role assigned in this ward' : labels.join(', ');
  }

  bool can(Capability capability, [String? wardId]) => assignments.any(
    (a) =>
        (wardId == null || a.wardId == wardId) &&
        (roleCapabilities[a.role]?.contains(capability) ?? false),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'wardIds': wardIds,
    'assignments': assignments.map((a) => a.toJson()).toList(),
    'skills': skills,
    'onDuty': onDuty,
    'availability': availability.name,
    'checkedInAt': checkedInAt?.toIso8601String(),
    'checkedOutAt': checkedOutAt?.toIso8601String(),
  };
  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    id: j['id'],
    name: j['name'],
    role: Role.values.byName(j['role']),
    wardIds: strings(j['wardIds']),
    assignments: j['assignments'] == null
        ? null
        : (j['assignments'] as List)
              .map((a) => WardRoleAssignment.fromJson(objectMap(a)))
              .toList(),
    skills: strings(j['skills']),
    onDuty: j['onDuty'],
    availability: Availability.values.byName(j['availability']),
    checkedInAt: j['checkedInAt'] == null ? null : instant(j['checkedInAt']),
    checkedOutAt: j['checkedOutAt'] == null ? null : instant(j['checkedOutAt']),
  );
}

class Resident {
  final String id, wardId, name, room;
  const Resident({
    required this.id,
    required this.wardId,
    required this.name,
    required this.room,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'name': name,
    'room': room,
  };
  factory Resident.fromJson(Map<String, dynamic> j) => Resident(
    id: j['id'],
    wardId: j['wardId'],
    name: j['name'],
    room: j['room'],
  );
}

class EventDraft {
  String idempotencyKey;
  EventType type;
  Priority priority;
  String? residentId, sourceMessageId;
  String subject, place, notes;
  DateTime occurredAt;
  DateTime? originalOccurredAt;
  List<String> mediaIds;
  EventDraft({
    required this.idempotencyKey,
    this.type = EventType.fall,
    Priority? priority,
    this.residentId,
    this.subject = '',
    this.place = '',
    this.notes = '',
    required this.occurredAt,
    this.sourceMessageId,
    this.originalOccurredAt,
    List<String>? mediaIds,
  }) : priority = priority ?? type.defaultPriority,
       mediaIds = mediaIds ?? [];
  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'type': type.name,
    'priority': priority.name,
    'residentId': residentId,
    'subject': subject,
    'place': place,
    'notes': notes,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'sourceMessageId': sourceMessageId,
    'mediaIds': mediaIds,
    'originalOccurredAt': originalOccurredAt?.toUtc().toIso8601String(),
  };
  factory EventDraft.fromJson(Map<String, dynamic> j) => EventDraft(
    idempotencyKey: j['idempotencyKey'],
    type: EventType.values.byName(j['type']),
    priority: Priority.values.byName(j['priority']),
    residentId: j['residentId'],
    subject: j['subject'] ?? '',
    place: j['place'] ?? '',
    notes: j['notes'] ?? '',
    occurredAt: instant(j['occurredAt']),
    sourceMessageId: j['sourceMessageId'],
    mediaIds: strings(j['mediaIds']),
    originalOccurredAt: j['originalOccurredAt'] == null
        ? null
        : instant(j['originalOccurredAt']),
  );
}

class RecordVersion {
  final int version;
  final String authorId, text;
  final DateTime createdAt;
  final bool ai;
  const RecordVersion({
    required this.version,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.ai = false,
  });
  Map<String, dynamic> toJson() => {
    'version': version,
    'authorId': authorId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'ai': ai,
  };
  factory RecordVersion.fromJson(Map<String, dynamic> j) => RecordVersion(
    version: j['version'],
    authorId: j['authorId'],
    text: j['text'],
    createdAt: instant(j['createdAt']),
    ai: j['ai'] ?? false,
  );
}

class CareEvent {
  final String id, wardId, authorId, idempotencyKey, correlationId;
  final EventType type;
  final Priority priority;
  final String? residentId, sourceMessageId;
  final String subject, place, notes;
  final DateTime occurredAt, registeredAt;
  DateTime? synchronizedAt, claimedAt, closedAt;
  String? claimedBy, closedBy, outcome;
  EventStatus status;
  SyncStatus syncStatus;
  String? syncError;
  final List<String> mediaIds;
  final List<RecordVersion> versions;
  CareEvent({
    required this.id,
    required this.wardId,
    required this.authorId,
    required this.idempotencyKey,
    required this.type,
    required this.priority,
    required this.occurredAt,
    required this.registeredAt,
    this.residentId,
    this.subject = '',
    this.place = '',
    this.notes = '',
    this.sourceMessageId,
    this.synchronizedAt,
    this.claimedAt,
    this.closedAt,
    this.claimedBy,
    this.closedBy,
    this.outcome,
    this.status = EventStatus.unhandled,
    this.syncStatus = SyncStatus.sent,
    this.syncError,
    List<String>? mediaIds,
    List<RecordVersion>? versions,
    String? correlationId,
  }) : mediaIds = mediaIds ?? [],
       versions = versions ?? [],
       correlationId = correlationId ?? id;
  String get conversationId => 'event-$id';
  String get diaryId => 'diary-$id';
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'authorId': authorId,
    'idempotencyKey': idempotencyKey,
    'correlationId': correlationId,
    'type': type.name,
    'priority': priority.name,
    'residentId': residentId,
    'subject': subject,
    'place': place,
    'notes': notes,
    'occurredAt': occurredAt.toIso8601String(),
    'registeredAt': registeredAt.toIso8601String(),
    'synchronizedAt': synchronizedAt?.toIso8601String(),
    'claimedAt': claimedAt?.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'claimedBy': claimedBy,
    'closedBy': closedBy,
    'outcome': outcome,
    'status': status.name,
    'syncStatus': syncStatus.name,
    'syncError': syncError,
    'sourceMessageId': sourceMessageId,
    'mediaIds': mediaIds,
    'versions': versions.map((v) => v.toJson()).toList(),
  };
  factory CareEvent.fromJson(Map<String, dynamic> j) => CareEvent(
    id: j['id'],
    wardId: j['wardId'],
    authorId: j['authorId'],
    idempotencyKey: j['idempotencyKey'],
    correlationId: j['correlationId'],
    type: EventType.values.byName(j['type']),
    priority: Priority.values.byName(j['priority']),
    residentId: j['residentId'],
    subject: j['subject'] ?? '',
    place: j['place'],
    notes: j['notes'],
    occurredAt: instant(j['occurredAt']),
    registeredAt: instant(j['registeredAt']),
    synchronizedAt: j['synchronizedAt'] == null
        ? null
        : instant(j['synchronizedAt']),
    claimedAt: j['claimedAt'] == null ? null : instant(j['claimedAt']),
    closedAt: j['closedAt'] == null ? null : instant(j['closedAt']),
    claimedBy: j['claimedBy'],
    closedBy: j['closedBy'],
    outcome: j['outcome'],
    status: EventStatus.values.byName(j['status']),
    syncStatus: SyncStatus.values.byName(j['syncStatus']),
    syncError: j['syncError'],
    sourceMessageId: j['sourceMessageId'],
    mediaIds: strings(j['mediaIds']),
    versions: (j['versions'] as List? ?? [])
        .map((v) => RecordVersion.fromJson(objectMap(v)))
        .toList(),
  );
}

class CareNotification {
  final String id, eventId, wardId;
  final List<String> recipientIds;
  final DateTime createdAt;
  DateTime? sentAt, deliveredAt, readAt, takenChargeAt, closedAt, remindedAt;
  DateTime deadline;
  int escalationLevel;
  CareNotification({
    required this.id,
    required this.eventId,
    required this.wardId,
    required this.recipientIds,
    required this.createdAt,
    required this.deadline,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.takenChargeAt,
    this.closedAt,
    this.remindedAt,
    this.escalationLevel = 0,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'wardId': wardId,
    'recipientIds': recipientIds,
    'createdAt': createdAt.toIso8601String(),
    'deadline': deadline.toIso8601String(),
    'sentAt': sentAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
    'readAt': readAt?.toIso8601String(),
    'takenChargeAt': takenChargeAt?.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'remindedAt': remindedAt?.toIso8601String(),
    'escalationLevel': escalationLevel,
  };
  factory CareNotification.fromJson(Map<String, dynamic> j) => CareNotification(
    id: j['id'],
    eventId: j['eventId'],
    wardId: j['wardId'],
    recipientIds: strings(j['recipientIds']),
    createdAt: instant(j['createdAt']),
    deadline: instant(j['deadline']),
    sentAt: j['sentAt'] == null ? null : instant(j['sentAt']),
    deliveredAt: j['deliveredAt'] == null ? null : instant(j['deliveredAt']),
    readAt: j['readAt'] == null ? null : instant(j['readAt']),
    takenChargeAt: j['takenChargeAt'] == null
        ? null
        : instant(j['takenChargeAt']),
    closedAt: j['closedAt'] == null ? null : instant(j['closedAt']),
    remindedAt: j['remindedAt'] == null ? null : instant(j['remindedAt']),
    escalationLevel: j['escalationLevel'],
  );
}

class Conversation {
  final String id, wardId, title;
  final ConversationKind kind;
  final List<String> memberIds;
  final String? eventId, ownerId;
  Conversation({
    required this.id,
    required this.wardId,
    required this.title,
    required this.kind,
    List<String>? memberIds,
    this.eventId,
    this.ownerId,
  }) : memberIds = memberIds ?? [];
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'title': title,
    'kind': kind.name,
    'memberIds': memberIds,
    'eventId': eventId,
    'ownerId': ownerId,
  };
  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'],
    wardId: j['wardId'],
    title: j['title'],
    kind: ConversationKind.values.byName(j['kind']),
    memberIds: strings(j['memberIds']),
    eventId: j['eventId'],
    ownerId: j['ownerId'],
  );
}

class Message {
  final String id, conversationId, authorId, text;
  final DateTime createdAt;
  final String? replyTo, mediaId;
  final List<String> sourceEventIds;
  final bool ai;
  String delivery;
  Message({
    required this.id,
    required this.conversationId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.replyTo,
    this.mediaId,
    List<String>? sourceEventIds,
    this.ai = false,
    this.delivery = 'Sent',
  }) : sourceEventIds = sourceEventIds ?? [];
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'authorId': authorId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'replyTo': replyTo,
    'mediaId': mediaId,
    'sourceEventIds': sourceEventIds,
    'ai': ai,
    'delivery': delivery,
  };
  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: j['id'],
    conversationId: j['conversationId'],
    authorId: j['authorId'],
    text: j['text'],
    createdAt: instant(j['createdAt']),
    replyTo: j['replyTo'],
    mediaId: j['mediaId'],
    sourceEventIds: strings(j['sourceEventIds']),
    ai: j['ai'] ?? false,
    delivery: j['delivery'] ?? 'Sent',
  );
}

class AssistantAnswer {
  final String text;
  final List<String> sourceEventIds;
  const AssistantAnswer(this.text, this.sourceEventIds);
}

class Handover {
  final String id, wardId, shift;

  /// Explicit ward/shift context. Older persisted records retain their label.
  final Shift? outgoingShift;
  HandoverStatus status;
  bool requiresClinicalValidation;
  int version;
  String? reviewedBy, validatedBy, signedBy;
  DateTime? reviewedAt, validatedAt, signedAt;
  String? draftText, originalDraftText, editedBy;
  DateTime? preparedAt, editedAt;
  bool needsDraftUpdate;

  /// Source content at signature, separate from live reports and their statuses.
  final List<Map<String, dynamic>> sourceSnapshots;
  final List<String> sourceEventIds, incomingStaffIds;
  final Map<String, String> acknowledgements;
  final List<RecordVersion> versions, contributions;
  Handover({
    required this.id,
    required this.wardId,
    this.shift = 'Morning · 07:00–14:00',
    this.outgoingShift,
    this.status = HandoverStatus.aiDraft,
    this.requiresClinicalValidation = false,
    this.version = 1,
    this.reviewedBy,
    this.validatedBy,
    this.signedBy,
    this.reviewedAt,
    this.validatedAt,
    this.signedAt,
    this.draftText,
    this.originalDraftText,
    this.editedBy,
    this.preparedAt,
    this.editedAt,
    this.needsDraftUpdate = false,
    List<Map<String, dynamic>>? sourceSnapshots,
    List<String>? sourceEventIds,
    List<String>? incomingStaffIds,
    Map<String, String>? acknowledgements,
    List<RecordVersion>? versions,
    List<RecordVersion>? contributions,
  }) : sourceSnapshots = sourceSnapshots ?? [],
       sourceEventIds = sourceEventIds ?? [],
       incomingStaffIds = incomingStaffIds ?? [],
       acknowledgements = acknowledgements ?? {},
       versions = versions ?? [],
       contributions = contributions ?? [];
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'shift': shift,
    'outgoingShift': outgoingShift?.toJson(),
    'requiresClinicalValidation': requiresClinicalValidation,
    'status': status.name,
    'version': version,
    'reviewedBy': reviewedBy,
    'validatedBy': validatedBy,
    'signedBy': signedBy,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'validatedAt': validatedAt?.toIso8601String(),
    'signedAt': signedAt?.toIso8601String(),
    'draftText': draftText,
    'originalDraftText': originalDraftText,
    'editedBy': editedBy,
    'preparedAt': preparedAt?.toIso8601String(),
    'editedAt': editedAt?.toIso8601String(),
    'needsDraftUpdate': needsDraftUpdate,
    'sourceSnapshots': sourceSnapshots,
    'sourceEventIds': sourceEventIds,
    'incomingStaffIds': incomingStaffIds,
    'acknowledgements': acknowledgements,
    'versions': versions.map((v) => v.toJson()).toList(),
    'contributions': contributions.map((v) => v.toJson()).toList(),
  };
  factory Handover.fromJson(Map<String, dynamic> j) => Handover(
    id: j['id'],
    wardId: j['wardId'],
    shift: j['shift'],
    outgoingShift: j['outgoingShift'] == null
        ? null
        : Shift.fromJson(objectMap(j['outgoingShift'])),
    requiresClinicalValidation: j['requiresClinicalValidation'] ?? false,
    status: HandoverStatus.values.byName(j['status']),
    version: j['version'],
    reviewedBy: j['reviewedBy'],
    validatedBy: j['validatedBy'],
    signedBy: j['signedBy'],
    reviewedAt: j['reviewedAt'] == null ? null : instant(j['reviewedAt']),
    validatedAt: j['validatedAt'] == null ? null : instant(j['validatedAt']),
    signedAt: j['signedAt'] == null ? null : instant(j['signedAt']),
    draftText: j['draftText'],
    originalDraftText: j['originalDraftText'],
    editedBy: j['editedBy'],
    preparedAt: j['preparedAt'] == null ? null : instant(j['preparedAt']),
    editedAt: j['editedAt'] == null ? null : instant(j['editedAt']),
    needsDraftUpdate: j['needsDraftUpdate'] ?? false,
    sourceSnapshots: (j['sourceSnapshots'] as List? ?? [])
        .map(objectMap)
        .toList(),
    sourceEventIds: strings(j['sourceEventIds']),
    incomingStaffIds: strings(j['incomingStaffIds']),
    acknowledgements: Map<String, String>.from(j['acknowledgements'] ?? {}),
    versions: (j['versions'] as List)
        .map((v) => RecordVersion.fromJson(objectMap(v)))
        .toList(),
    contributions: (j['contributions'] as List)
        .map((v) => RecordVersion.fromJson(objectMap(v)))
        .toList(),
  );
}

class OcrItem {
  final String id, wardId, originalText;
  final String title;
  final String? sourceMediaId, sourceFingerprint, extractionError;
  final DateTime? createdAt;
  final List<String> uncertainSegments;
  final List<RecordVersion> versions;
  String? correctedText, reviewedBy;
  DateTime? reviewedAt;
  OcrItem({
    required this.id,
    required this.wardId,
    required this.originalText,
    this.title = 'Equipment check',
    this.sourceMediaId,
    this.sourceFingerprint,
    this.extractionError,
    this.createdAt,
    List<String>? uncertainSegments,
    List<RecordVersion>? versions,
    this.correctedText,
    this.reviewedBy,
    this.reviewedAt,
  }) : uncertainSegments = uncertainSegments ?? [],
       versions = versions ?? [];
  bool get hasExtraction => originalText.trim().isNotEmpty;
  bool get isReviewed => reviewedAt != null;
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'originalText': originalText,
    'title': title,
    'sourceMediaId': sourceMediaId,
    'sourceFingerprint': sourceFingerprint,
    'extractionError': extractionError,
    'createdAt': createdAt?.toIso8601String(),
    'uncertainSegments': uncertainSegments,
    'versions': versions.map((v) => v.toJson()).toList(),
    'correctedText': correctedText,
    'reviewedBy': reviewedBy,
    'reviewedAt': reviewedAt?.toIso8601String(),
  };
  factory OcrItem.fromJson(Map<String, dynamic> j) => OcrItem(
    id: j['id'],
    wardId: j['wardId'],
    originalText: j['originalText'],
    title: j['title'] ?? 'Equipment check',
    sourceMediaId: j['sourceMediaId'],
    sourceFingerprint: j['sourceFingerprint'],
    extractionError: j['extractionError'],
    createdAt: j['createdAt'] == null ? null : instant(j['createdAt']),
    uncertainSegments: strings(j['uncertainSegments']),
    versions: (j['versions'] as List? ?? [])
        .map((v) => RecordVersion.fromJson(objectMap(v)))
        .toList(),
    correctedText: j['correctedText'],
    reviewedBy: j['reviewedBy'],
    reviewedAt: j['reviewedAt'] == null ? null : instant(j['reviewedAt']),
  );
}

class AuditEntry {
  final String id, actorId, action, recordId, fingerprint;
  final DateTime createdAt;
  const AuditEntry({
    required this.id,
    required this.actorId,
    required this.action,
    required this.recordId,
    required this.createdAt,
    required this.fingerprint,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'actorId': actorId,
    'action': action,
    'recordId': recordId,
    'createdAt': createdAt.toIso8601String(),
    'fingerprint': fingerprint,
  };
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: j['id'],
    actorId: j['actorId'],
    action: j['action'],
    recordId: j['recordId'],
    createdAt: instant(j['createdAt']),
    fingerprint: j['fingerprint'],
  );
}

class MediaRecord {
  final String id, wardId, authorId, mimeType, base64Data, label;
  final bool synthetic;
  final int? durationMs;
  final String? transcript;
  final DateTime createdAt;
  const MediaRecord({
    required this.id,
    required this.wardId,
    required this.authorId,
    required this.mimeType,
    required this.base64Data,
    required this.label,
    required this.createdAt,
    this.synthetic = false,
    this.durationMs,
    this.transcript,
  });
  List<int> get bytes => base64Decode(base64Data);
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'authorId': authorId,
    'mimeType': mimeType,
    'base64Data': base64Data,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
    'synthetic': synthetic,
    'durationMs': durationMs,
    'transcript': transcript,
  };
  factory MediaRecord.fromJson(Map<String, dynamic> j) => MediaRecord(
    id: j['id'],
    wardId: j['wardId'],
    authorId: j['authorId'],
    mimeType: j['mimeType'],
    base64Data: j['base64Data'],
    label: j['label'],
    createdAt: instant(j['createdAt']),
    synthetic: j['synthetic'] ?? false,
    durationMs: j['durationMs'],
    transcript: j['transcript'],
  );
}

/// Facility-local wall-clock boundaries are converted to UTC for persistence.
/// Constructing each boundary separately preserves Europe/Rome DST transitions.
class FacilityTime {
  static const zoneName = 'Europe/Rome';
  static bool _initialized = false;
  static tz.Location get location {
    if (!_initialized) {
      tzdata.initializeTimeZones();
      _initialized = true;
    }
    return tz.getLocation(zoneName);
  }

  static tz.TZDateTime local(DateTime instant) =>
      tz.TZDateTime.from(instant.toUtc(), location);
}

class Shift {
  final String id, wardId, label;
  final DateTime startsAt, endsAt;
  const Shift({
    required this.id,
    required this.wardId,
    required this.label,
    required this.startsAt,
    required this.endsAt,
  });
  factory Shift.at(DateTime instant, String wardId) {
    final local = FacilityTime.local(instant);
    final int startDay;
    final int startHour;
    final int endDay;
    final int endHour;
    final String label;
    if (local.hour >= 7 && local.hour < 14) {
      startDay = local.day;
      startHour = 7;
      endDay = local.day;
      endHour = 14;
      label = 'Morning';
    } else if (local.hour >= 14 && local.hour < 21) {
      startDay = local.day;
      startHour = 14;
      endDay = local.day;
      endHour = 21;
      label = 'Afternoon';
    } else {
      startDay = local.hour >= 21 ? local.day : local.day - 1;
      startHour = 21;
      endDay = startDay + 1;
      endHour = 7;
      label = 'Night';
    }
    final start = tz.TZDateTime(
      FacilityTime.location,
      local.year,
      local.month,
      startDay,
      startHour,
    );
    final end = tz.TZDateTime(
      FacilityTime.location,
      local.year,
      local.month,
      endDay,
      endHour,
    );
    final date =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    return Shift(
      id: 'shift-$wardId-$date-${label.toLowerCase()}',
      wardId: wardId,
      label: label,
      startsAt: start.toUtc(),
      endsAt: end.toUtc(),
    );
  }
  bool contains(DateTime instant) =>
      !instant.toUtc().isBefore(startsAt) && instant.toUtc().isBefore(endsAt);
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'label': label,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
  };
  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
    id: j['id'],
    wardId: j['wardId'],
    label: j['label'],
    startsAt: instant(j['startsAt']),
    endsAt: instant(j['endsAt']),
  );
}

class Attendance {
  final String id, staffId, wardId, shiftId;
  final bool onDuty;
  final Availability availability;
  final DateTime? checkedInAt, checkedOutAt;
  const Attendance({
    required this.id,
    required this.staffId,
    required this.wardId,
    required this.shiftId,
    required this.onDuty,
    required this.availability,
    this.checkedInAt,
    this.checkedOutAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'staffId': staffId,
    'wardId': wardId,
    'shiftId': shiftId,
    'onDuty': onDuty,
    'availability': availability.name,
    'checkedInAt': checkedInAt?.toUtc().toIso8601String(),
    'checkedOutAt': checkedOutAt?.toUtc().toIso8601String(),
  };
  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
    id: j['id'],
    staffId: j['staffId'],
    wardId: j['wardId'],
    shiftId: j['shiftId'],
    onDuty: j['onDuty'],
    availability: Availability.values.byName(j['availability']),
    checkedInAt: j['checkedInAt'] == null ? null : instant(j['checkedInAt']),
    checkedOutAt: j['checkedOutAt'] == null ? null : instant(j['checkedOutAt']),
  );
}

class DiaryEntry {
  final String id, eventId, wardId, authorId;
  final DateTime occurredAt, registeredAt;
  final List<RecordVersion> versions;
  const DiaryEntry({
    required this.id,
    required this.eventId,
    required this.wardId,
    required this.authorId,
    required this.occurredAt,
    required this.registeredAt,
    required this.versions,
  });
  factory DiaryEntry.fromEvent(CareEvent event) => DiaryEntry(
    id: event.diaryId,
    eventId: event.id,
    wardId: event.wardId,
    authorId: event.authorId,
    occurredAt: event.occurredAt,
    registeredAt: event.registeredAt,
    versions: List.unmodifiable(event.versions),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'wardId': wardId,
    'authorId': authorId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'registeredAt': registeredAt.toUtc().toIso8601String(),
    'versions': versions.map((v) => v.toJson()).toList(),
  };
  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
    id: j['id'],
    eventId: j['eventId'],
    wardId: j['wardId'],
    authorId: j['authorId'],
    occurredAt: instant(j['occurredAt']),
    registeredAt: instant(j['registeredAt']),
    versions: (j['versions'] as List)
        .map((v) => RecordVersion.fromJson(objectMap(v)))
        .toList(),
  );
}

class StaffSummary {
  final String id, wardId, shiftId, handoverId, authorId, text;
  final DateTime createdAt;
  final List<String> sourceEventIds;
  const StaffSummary({
    required this.id,
    required this.wardId,
    required this.shiftId,
    required this.handoverId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    required this.sourceEventIds,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'shiftId': shiftId,
    'handoverId': handoverId,
    'authorId': authorId,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sourceEventIds': sourceEventIds,
  };
  factory StaffSummary.fromJson(Map<String, dynamic> j) => StaffSummary(
    id: j['id'],
    wardId: j['wardId'],
    shiftId: j['shiftId'],
    handoverId: j['handoverId'],
    authorId: j['authorId'],
    text: j['text'],
    createdAt: instant(j['createdAt']),
    sourceEventIds: strings(j['sourceEventIds']),
  );
}

class RoutingRule {
  final String id, wardId;
  final Priority priority;
  final List<Role> initialRoles, escalationRoles;
  final Duration? reminderAfter, escalationAfter;
  final bool quiet;
  const RoutingRule({
    required this.id,
    required this.wardId,
    required this.priority,
    required this.initialRoles,
    required this.escalationRoles,
    this.reminderAfter,
    this.escalationAfter,
    this.quiet = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'wardId': wardId,
    'priority': priority.name,
    'initialRoles': initialRoles.map((r) => r.name).toList(),
    'escalationRoles': escalationRoles.map((r) => r.name).toList(),
    'reminderAfterMs': reminderAfter?.inMilliseconds,
    'escalationAfterMs': escalationAfter?.inMilliseconds,
    'quiet': quiet,
  };
  factory RoutingRule.fromJson(Map<String, dynamic> j) => RoutingRule(
    id: j['id'],
    wardId: j['wardId'],
    priority: Priority.values.byName(j['priority']),
    initialRoles: strings(j['initialRoles']).map(Role.values.byName).toList(),
    escalationRoles: strings(
      j['escalationRoles'],
    ).map(Role.values.byName).toList(),
    reminderAfter: j['reminderAfterMs'] == null
        ? null
        : Duration(milliseconds: j['reminderAfterMs']),
    escalationAfter: j['escalationAfterMs'] == null
        ? null
        : Duration(milliseconds: j['escalationAfterMs']),
    quiet: j['quiet'] ?? false,
  );
}
