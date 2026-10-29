import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';
import 'models.dart';

class PermissionDenied implements Exception {
  final String message;
  const PermissionDenied([
    this.message = 'You do not have permission to access this record.',
  ]);
  @override
  String toString() => message;
}

/// Boundary for a future authenticated FastAPI/realtime repository adapter.
/// All domain mutations are asynchronous and authorization is checked here.
abstract interface class EventRepository {
  List<CareEvent> get events;
  Future<CareEvent> reportEvent(EventDraft draft);
  Future<void> claimEvent(String id);
  Future<void> closeEvent(String id, String outcome);
}

class RsaRepository extends ChangeNotifier implements EventRepository {
  final RsaDatabase database;
  final DateTime Function() _clock;
  final _uuid = const Uuid();
  Future<void> _tail = Future.value();
  final _updates = StreamController<void>.broadcast();
  String _personaId = 'nurse-1';
  String _wardId = 'oak';
  bool _online = true;
  Duration _offset = Duration.zero;
  List<Ward> _wards = [];
  List<StaffMember> _staff = [];
  List<Resident> _residents = [];
  List<CareEvent> _events = [];
  List<CareNotification> _notifications = [];
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  List<Handover> _handovers = [];
  String? _selectedHandoverId;
  List<OcrItem> _ocr = [];
  List<AuditEntry> _auditEntries = [];
  List<MediaRecord> _media = [];
  Map<String, EventDraft> _drafts = {};
  final Map<String, int> _readCounts = {};
  final Set<String> _openedEventConversations = {};
  Map<String, Map<String, dynamic>> _chatDrafts = {};
  bool _disposed = false;
  Future<void>? _closeFuture;
  String? lastSyncError;
  int highTimeoutMinutes = 2;
  int mediumReminderMinutes = 5;
  int mediumEscalationMinutes = 10;

  RsaRepository(this.database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  static Future<RsaRepository> open({
    RsaDatabase? database,
    DateTime Function()? clock,
  }) async {
    final repo = RsaRepository(
      database ?? await RsaDatabase.open(),
      clock: clock,
    );
    await repo.initialize();
    return repo;
  }

  Stream<void> get changes => _updates.stream;
  DateTime get now => _clock().toUtc().add(_offset);
  bool get online => _online;
  StaffMember get currentUser => _staff.firstWhere((s) => s.id == _personaId);
  List<StaffMember> get personas => List.unmodifiable(_staff);
  List<Ward> get wards => List.unmodifiable(
    _wards.where(
      (w) =>
          currentUser.wardIds.contains(w.id) || can(Capability.administration),
    ),
  );
  Ward get activeWard => _wards.firstWhere((w) => w.id == _wardId);
  bool can(Capability capability) =>
      currentUser.can(capability, switch (capability) {
        Capability.administration ||
        Capability.audit ||
        Capability.management => null,
        _ => _wardId,
      });
  bool _scope(String wardId) => currentUser.wardIds.contains(wardId);
  void _require(Capability capability, [String? wardId]) {
    if (!(wardId == null
        ? can(capability)
        : currentUser.can(capability, wardId))) {
      throw const PermissionDenied();
    }
  }

  List<StaffMember> get staff {
    if (can(Capability.administration)) return List.unmodifiable(_staff);
    _require(Capability.care, _wardId);
    return List.unmodifiable(
      _staff.where((s) => s.can(Capability.care, _wardId)),
    );
  }

  StaffMember? staffById(String id) {
    if (id == 'assistant') return null;
    final s = _staff.where((s) => s.id == id).firstOrNull;
    if (s == null) return null;
    if (s.id == _personaId ||
        can(Capability.administration) ||
        (can(Capability.care) &&
            s.wardIds.any(
              (ward) =>
                  currentUser.can(Capability.care, ward) &&
                  s.can(Capability.care, ward),
            ))) {
      return s;
    }
    throw const PermissionDenied();
  }

  /// A retained record can reference a colleague who has since left the ward.
  /// Presentation may fall back to that record's actor ID without resolving an
  /// out-of-scope staff profile. The strict lookup still enforces authorization.
  StaffMember? staffForDisplay(String id) {
    try {
      return staffById(id);
    } on PermissionDenied {
      return null;
    }
  }

  List<Resident> get residents {
    _require(Capability.care, _wardId);
    return List.unmodifiable(_residents.where((r) => r.wardId == _wardId));
  }

  Resident? residentById(String id) {
    _require(Capability.care);
    final r = _residents.where((r) => r.id == id).firstOrNull;
    if (r != null) _require(Capability.care, r.wardId);
    return r;
  }

  @override
  List<CareEvent> get events {
    _require(Capability.diary, _wardId);
    final list = _events.where((e) => e.wardId == _wardId).toList();
    list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(list);
  }

  CareEvent? eventById(String id) {
    _require(Capability.diary);
    final e = _events.where((e) => e.id == id).firstOrNull;
    if (e != null) _require(Capability.diary, e.wardId);
    return e;
  }

  List<CareNotification> get notifications {
    _require(Capability.care, _wardId);
    return List.unmodifiable(
      _notifications.where(
        (n) =>
            n.wardId == _wardId &&
            (n.recipientIds.contains(_personaId) ||
                can(Capability.coordination)),
      ),
    );
  }

  List<CareEvent> get inboxEvents =>
      notifications
          .map((n) => eventById(n.eventId))
          .whereType<CareEvent>()
          .toList()
        ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  List<CareEvent> get outbox => events
      .where((e) => e.authorId == _personaId && e.syncStatus != SyncStatus.sent)
      .toList();
  String get _draftKey => '$_personaId:$_wardId';
  EventDraft? get draft {
    _require(Capability.report, _wardId);
    return _drafts[_draftKey];
  }

  Shift get currentShift {
    _require(Capability.care, _wardId);
    return Shift.at(now, _wardId);
  }

  List<Shift> get shifts {
    _require(Capability.care, _wardId);
    final local = FacilityTime.local(now);
    // Include the previous overnight shift and the three shifts starting today.
    final midnight = DateTime.utc(local.year, local.month, local.day);
    final samples = [
      midnight,
      midnight.add(const Duration(hours: 8)),
      midnight.add(const Duration(hours: 15)),
      midnight.add(const Duration(hours: 22)),
    ];
    final unique = <String, Shift>{};
    for (final sample in samples) {
      final shift = Shift.at(sample, _wardId);
      unique[shift.id] = shift;
    }
    return List.unmodifiable(unique.values);
  }

  List<Attendance> get attendance {
    final shift = currentShift;
    return List.unmodifiable(
      staff.map(
        (s) => Attendance(
          id: 'attendance-${s.id}-${shift.id}',
          staffId: s.id,
          wardId: _wardId,
          shiftId: shift.id,
          onDuty: s.onDuty,
          availability: s.availability,
          checkedInAt: s.checkedInAt,
          checkedOutAt: s.checkedOutAt,
        ),
      ),
    );
  }

  List<DiaryEntry> get diaryEntries =>
      List.unmodifiable(events.map(DiaryEntry.fromEvent));
  List<StaffSummary> get staffSummaries {
    _require(Capability.diary, _wardId);
    final list = <StaffSummary>[];
    for (final h in handovers) {
      for (var index = 0; index < h.contributions.length; index++) {
        final contribution = h.contributions[index];
        list.add(
          StaffSummary(
            id: 'summary-${h.id}-$index',
            wardId: h.wardId,
            shiftId:
                h.outgoingShift?.id ??
                Shift.at(contribution.createdAt, h.wardId).id,
            handoverId: h.id,
            authorId: contribution.authorId,
            text: contribution.text,
            createdAt: contribution.createdAt,
            sourceEventIds: List.unmodifiable(h.sourceEventIds),
          ),
        );
      }
    }
    return List.unmodifiable(list);
  }

  List<RoutingRule> get routingRules {
    if (!can(Capability.administration) && !can(Capability.coordination)) {
      throw const PermissionDenied();
    }
    return List.unmodifiable([
      RoutingRule(
        id: 'routing-$_wardId-high',
        wardId: _wardId,
        priority: Priority.high,
        initialRoles: const [Role.nurse, Role.coordinator],
        escalationRoles: const [Role.coordinator],
        escalationAfter: Duration(minutes: highTimeoutMinutes),
      ),
      RoutingRule(
        id: 'routing-$_wardId-medium',
        wardId: _wardId,
        priority: Priority.medium,
        initialRoles: const [Role.nurse],
        escalationRoles: const [Role.coordinator],
        reminderAfter: Duration(minutes: mediumReminderMinutes),
        escalationAfter: Duration(minutes: mediumEscalationMinutes),
        quiet: true,
      ),
      RoutingRule(
        id: 'routing-$_wardId-low',
        wardId: _wardId,
        priority: Priority.low,
        initialRoles: const [],
        escalationRoles: const [],
      ),
    ]);
  }

  List<Handover> get handovers {
    _require(Capability.diary, _wardId);
    return List.unmodifiable(_handovers.where((h) => h.wardId == _wardId));
  }

  Handover get handover =>
      handovers.where((h) => h.id == _selectedHandoverId).firstOrNull ??
      handovers.first;
  List<OcrItem> get ocrItems {
    _require(Capability.care, _wardId);
    return List.unmodifiable(_ocr.where((o) => o.wardId == _wardId));
  }

  List<AuditEntry> get audit {
    _require(Capability.audit);
    return List.unmodifiable(_auditEntries.reversed);
  }

  List<Conversation> get conversations {
    _require(Capability.chat, _wardId);
    return List.unmodifiable(
      _conversations.where(
        (c) =>
            c.wardId == _wardId &&
            _canConversation(c) &&
            (c.kind != ConversationKind.event ||
                _openedEventConversations.contains('$_personaId:${c.id}')),
      ),
    );
  }

  /// People with whom the current account may start a conversation in this ward.
  /// Attendance does not remove an assigned colleague from the address book.
  List<StaffMember> get conversationContacts {
    _require(Capability.chat, _wardId);
    final contacts =
        _staff
            .where((s) => s.id != _personaId && s.can(Capability.chat, _wardId))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(contacts);
  }

  String conversationTitle(Conversation conversation) {
    final accessible = _conversation(conversation.id);
    if (accessible.kind != ConversationKind.direct) return accessible.title;
    final otherIds = accessible.memberIds.where((id) => id != _personaId);
    final names = otherIds
        .map((id) => _staff.where((s) => s.id == id).firstOrNull?.name)
        .whereType<String>()
        .toList();
    return names.isEmpty ? accessible.title : names.join(', ');
  }

  /// Opening an event discussion adds it to this account's conversation list.
  /// This preference does not change who can access the underlying ward event.
  Future<Conversation> openEventConversation(String eventId) => _mutate(() {
    _require(Capability.chat, _wardId);
    final event = eventById(eventId);
    if (event == null || event.wardId != _wardId) {
      throw const PermissionDenied();
    }
    var conversation = _conversations
        .where((c) => c.id == event.conversationId)
        .firstOrNull;
    if (conversation == null) {
      conversation = Conversation(
        id: event.conversationId,
        wardId: event.wardId,
        title: '${event.type.label} · ${event.residentId ?? event.subject}',
        kind: ConversationKind.event,
        eventId: event.id,
      );
      _conversations.add(conversation);
    }
    _openedEventConversations.add('$_personaId:${conversation.id}');
    return conversation;
  });

  Future<Conversation> startDirectConversation(String staffId) => _mutate(() {
    _require(Capability.chat, _wardId);
    final colleague = _staff.where((s) => s.id == staffId).firstOrNull;
    if (colleague == null ||
        colleague.id == _personaId ||
        !colleague.can(Capability.chat, _wardId)) {
      throw const PermissionDenied(
        'Choose a colleague assigned to the current ward.',
      );
    }
    final existing = _conversations
        .where(
          (c) =>
              c.kind == ConversationKind.direct &&
              c.wardId == _wardId &&
              c.memberIds.length == 2 &&
              c.memberIds.contains(_personaId) &&
              c.memberIds.contains(staffId),
        )
        .firstOrNull;
    if (existing != null) return existing;
    final conversation = Conversation(
      id: _uuid.v4(),
      wardId: _wardId,
      title: colleague.name,
      kind: ConversationKind.direct,
      memberIds: [_personaId, staffId],
    );
    _conversations.add(conversation);
    _log('Direct conversation opened', conversation.id);
    return conversation;
  });

  bool _canConversation(Conversation c) =>
      currentUser.can(Capability.chat, c.wardId) &&
      (c.kind == ConversationKind.assistant
          ? c.ownerId == _personaId
          : c.kind == ConversationKind.direct
          ? c.memberIds.contains(_personaId)
          : true);
  Conversation _conversation(String id) {
    final c = _conversations.where((c) => c.id == id).firstOrNull;
    if (c == null || !_canConversation(c)) throw const PermissionDenied();
    return c;
  }

  List<Message> messagesFor(String conversationId) {
    _conversation(conversationId);
    return List.unmodifiable(
      _messages.where((m) => m.conversationId == conversationId),
    );
  }

  Message? messageById(String id) {
    final m = _messages.where((m) => m.id == id).firstOrNull;
    if (m != null) _conversation(m.conversationId);
    return m;
  }

  Map<String, dynamic>? chatDraftFor(String conversationId) {
    _conversation(conversationId);
    final draft = _chatDrafts['$_personaId:$conversationId'];
    return draft == null ? null : Map.unmodifiable(draft);
  }

  Future<void> saveChatDraft(
    String conversationId,
    String text, {
    String? mediaId,
    String? replyTo,
  }) => _mutate(() {
    _conversation(conversationId);
    if (mediaId != null && mediaById(mediaId) == null) {
      throw StateError('Attachment is unavailable.');
    }
    if (replyTo != null &&
        messageById(replyTo)?.conversationId != conversationId) {
      throw const PermissionDenied();
    }
    _chatDrafts['$_personaId:$conversationId'] = {
      'text': text,
      'mediaId': mediaId,
      'replyTo': replyTo,
    };
  });
  int unreadCount(String conversationId) {
    final messages = messagesFor(conversationId);
    final read = _readCounts['$_personaId:$conversationId'] ?? 0;
    return (messages.length - read).clamp(0, messages.length);
  }

  MediaRecord? mediaById(String id) {
    _require(Capability.care);
    final m = _media.where((m) => m.id == id).firstOrNull;
    if (m != null) {
      _require(Capability.care, m.wardId);
      final inEvent = _events.any(
        (e) =>
            currentUser.can(Capability.diary, e.wardId) &&
            e.mediaIds.contains(id),
      );
      final inConversation = _messages.any(
        (message) =>
            message.mediaId == id &&
            _conversations.any(
              (c) => c.id == message.conversationId && _canConversation(c),
            ),
      );
      final inDocument = _ocr.any(
        (o) =>
            o.sourceMediaId == id && currentUser.can(Capability.care, o.wardId),
      );
      if (m.authorId != _personaId &&
          !inEvent &&
          !inConversation &&
          !inDocument) {
        throw const PermissionDenied();
      }
    }
    return m;
  }

  Future<void> initialize() async {
    final rows = await database
        .customSelect('SELECT body FROM snapshot WHERE id = 1')
        .get();
    if (rows.isEmpty) {
      _seed();
      await _persist();
      for (final e in _events) {
        await database.customStatement(
          'INSERT OR IGNORE INTO event_keys VALUES (?, ?)',
          [e.idempotencyKey, e.id],
        );
        if (e.claimedBy != null) {
          await database.customStatement(
            'INSERT OR IGNORE INTO event_claims VALUES (?, ?, ?)',
            [e.id, e.claimedBy, e.claimedAt!.toIso8601String()],
          );
        }
      }
    } else {
      _restore(objectMap(jsonDecode(rows.first.read<String>('body'))));
    }
    await _mutate<void>(() async {
      if (_online) await _syncPending();
      _evaluateEscalation();
    });
  }

  Future<T> _mutate<T>(FutureOr<T> Function() operation) {
    final result = Completer<T>();
    final requestingPersona = _personaId;
    final requestingWard = _wardId;
    _tail = _tail.then((_) async {
      final before = jsonEncode(_serialize());
      try {
        if (_personaId != requestingPersona || _wardId != requestingWard) {
          throw const PermissionDenied(
            'The active persona or ward changed. Review and retry the action.',
          );
        }
        final value = await database.transaction(() async {
          final v = await operation();
          await _persist();
          return v;
        });
        if (!_disposed) notifyListeners();
        if (!_updates.isClosed) _updates.add(null);
        result.complete(value);
      } catch (e, st) {
        _restore(objectMap(jsonDecode(before)));
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  Future<void> _persist() => database.customStatement(
    'INSERT INTO snapshot (id,body) VALUES (1,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body',
    [jsonEncode(_serialize())],
  );
  void _log(String action, String recordId, [String content = '']) {
    _auditEntries.add(
      AuditEntry(
        id: _uuid.v4(),
        actorId: _personaId,
        action: action,
        recordId: recordId,
        createdAt: now,
        fingerprint: sha256
            .convert(
              utf8.encode(
                '$action:$recordId:$content:${now.toIso8601String()}',
              ),
            )
            .toString(),
      ),
    );
  }

  Future<void> switchPersona(String id) => _mutate(() {
    final person = _staff.where((s) => s.id == id).firstOrNull;
    if (person == null) throw const PermissionDenied();
    _personaId = id;
    _wardId = person.wardIds.firstOrNull ?? _wards.first.id;
    _ensureAssistant();
    _log('Demo persona selected', id);
  });
  Future<void> selectWard(String id) => _mutate(() {
    if (!_scope(id) && !can(Capability.administration)) {
      throw const PermissionDenied();
    }
    if (!_wards.any((w) => w.id == id)) throw const PermissionDenied();
    _wardId = id;
    _ensureAssistant();
  });
  Future<void> setOnline(bool value) => _mutate(() async {
    _online = value;
    if (value) await _syncPending();
    _log(
      value ? 'Demo connection restored' : 'Demo offline enabled',
      _personaId,
    );
  });
  Future<void> synchronize() => _mutate(() async {
    if (_online) await _syncPending();
    _evaluateEscalation();
  });
  Future<void> setAvailability(Availability value) => _mutate(() {
    _require(Capability.care, _wardId);
    currentUser.availability = value;
    _log('Availability updated', _personaId, value.name);
  });
  Future<void> toggleAttendance() => _mutate(() {
    _require(Capability.care, _wardId);
    currentUser.onDuty = !currentUser.onDuty;
    if (currentUser.onDuty) {
      currentUser.checkedInAt = now;
    } else {
      currentUser.checkedOutAt = now;
    }
    _log(currentUser.onDuty ? 'Checked in' : 'Checked out', _personaId);
  });
  Future<void> updateStaff(
    String id, {
    Role? role,
    List<String>? wardIds,
    List<String>? skills,
    bool? onDuty,
    Availability? availability,
  }) => _mutate(() {
    final s = _staff.where((s) => s.id == id).firstOrNull;
    if (s == null) throw const PermissionDenied();
    if (can(Capability.administration)) {
      if (role != null || wardIds != null) {
        final nextWardIds = wardIds ?? s.wardIds;
        if (nextWardIds.isEmpty ||
            nextWardIds.any((id) => !_wards.any((w) => w.id == id))) {
          throw StateError('Choose a valid ward.');
        }
        s.role = role ?? s.role;
        s.wardIds = nextWardIds;
      }
    } else {
      _require(Capability.coordination, _wardId);
      if (!s.wardIds.contains(_wardId) || role != null || wardIds != null) {
        throw const PermissionDenied();
      }
    }
    if (skills != null) s.skills = skills;
    if (onDuty != null) s.onDuty = onDuty;
    if (availability != null) s.availability = availability;
    _log('Staff assignment updated', id);
  });
  Future<void> updateAssignments(
    String id,
    List<WardRoleAssignment> assignments,
  ) => _mutate(() {
    _require(Capability.administration);
    final person = _staff.where((s) => s.id == id).firstOrNull;
    if (person == null ||
        assignments.isEmpty ||
        assignments.any((a) => !_wards.any((w) => w.id == a.wardId))) {
      throw const PermissionDenied();
    }
    final identities = assignments
        .map((a) => '${a.wardId}:${a.role.name}')
        .toSet();
    if (identities.length != assignments.length) {
      throw StateError('Each ward-role assignment must be unique.');
    }
    person.assignments = List.of(assignments);
    _log(
      'Explicit ward roles assigned',
      id,
      jsonEncode(assignments.map((a) => a.toJson()).toList()),
    );
  });
  Future<void> renameWard(String id, String name) => _mutate(() {
    if (!can(Capability.administration) &&
        !currentUser.can(Capability.management, id)) {
      throw const PermissionDenied();
    }
    final index = _wards.indexWhere((ward) => ward.id == id);
    final value = name.trim();
    if (index < 0 || value.isEmpty || value.length > 100) {
      throw StateError('Enter a valid ward name of up to 100 characters.');
    }
    _wards[index] = Ward(id, value);
    _log('Ward configuration updated', id);
  });
  Future<void> configureRouting({
    required int highMinutes,
    required int reminderMinutes,
    required int escalationMinutes,
  }) => _mutate(() {
    _require(Capability.administration);
    if (highMinutes <= 0 ||
        reminderMinutes <= 0 ||
        escalationMinutes <= reminderMinutes ||
        highMinutes > 1440 ||
        escalationMinutes > 1440) {
      throw StateError(
        'Use positive minute values up to 1440. Escalation must follow the reminder.',
      );
    }
    highTimeoutMinutes = highMinutes;
    mediumReminderMinutes = reminderMinutes;
    mediumEscalationMinutes = escalationMinutes;
    _log('Facility alert timing updated', 'routing-policy');
  });
  List<StaffMember> eligibleRecipients(CareEvent event) {
    _require(Capability.care, event.wardId);
    return _eligible(event);
  }

  List<StaffMember> _eligible(CareEvent event, {bool coordinatorOnly = false}) {
    if (event.priority == Priority.low) return [];
    final present = _staff
        .where(
          (s) =>
              s.wardIds.contains(event.wardId) &&
              s.onDuty &&
              s.can(Capability.claim, event.wardId) &&
              s.skills.contains('Nursing') &&
              (coordinatorOnly
                  ? s.hasRole(Role.coordinator, event.wardId)
                  : (event.priority == Priority.high ||
                        s.hasRole(Role.nurse, event.wardId))),
        )
        .toList();
    final available = present
        .where((s) => s.availability == Availability.available)
        .toList();
    if (event.priority == Priority.high) {
      // Busy staff remain eligible for urgent notifications; on-break staff do not.
      return present
          .where((s) => s.availability != Availability.onBreak)
          .toList();
    }
    return available;
  }

  bool canClaim(CareEvent event) =>
      currentUser.can(Capability.claim, event.wardId) &&
      event.syncStatus == SyncStatus.sent &&
      event.status == EventStatus.unhandled &&
      (_eligible(event).any((s) => s.id == _personaId) ||
          (currentUser.hasRole(Role.coordinator, event.wardId) &&
              currentUser.onDuty &&
              currentUser.availability == Availability.available &&
              currentUser.skills.contains('Nursing') &&
              _notifications.any(
                (n) =>
                    n.eventId == event.id &&
                    n.escalationLevel > 0 &&
                    n.recipientIds.contains(_personaId),
              )));
  Future<void> saveDraft(EventDraft? value) => _mutate(() {
    _require(Capability.report, _wardId);
    if (value == null) {
      _drafts.remove(_draftKey);
    } else {
      _validateDraft(value);
      _drafts[_draftKey] = EventDraft.fromJson(value.toJson());
    }
  });
  void _validateDraft(EventDraft draft) {
    if (draft.residentId != null) {
      final resident = _residents
          .where((r) => r.id == draft.residentId)
          .firstOrNull;
      if (resident == null ||
          resident.wardId != _wardId ||
          !_scope(resident.wardId)) {
        throw const PermissionDenied();
      }
    }
    if (draft.sourceMessageId != null &&
        messageById(draft.sourceMessageId!) == null) {
      throw const PermissionDenied();
    }
    for (final id in draft.mediaIds) {
      if (mediaById(id) == null) throw StateError('Attachment is unavailable.');
    }
  }

  @override
  Future<CareEvent> reportEvent(EventDraft draft) => _mutate(() async {
    _require(Capability.report, _wardId);
    _validateDraft(draft);
    final existing = _events
        .where(
          (e) =>
              e.idempotencyKey == draft.idempotencyKey ||
              (draft.sourceMessageId != null &&
                  e.sourceMessageId == draft.sourceMessageId),
        )
        .firstOrNull;
    if (existing != null) {
      _require(Capability.report, existing.wardId);
      return existing;
    }
    if (draft.residentId == null && draft.subject.trim().isEmpty) {
      throw StateError('Choose a resident or describe the subject.');
    }
    final id = _uuid.v4();
    await database.customStatement(
      'INSERT INTO event_keys (idempotency_key,event_id) VALUES (?,?)',
      [draft.idempotencyKey, id],
    );
    final changes = <String>[draft.notes];
    if (draft.priority != draft.type.defaultPriority) {
      changes.add(
        'Operational priority changed from ${draft.type.defaultPriority.label} to ${draft.priority.label}.',
      );
    }
    if (draft.originalOccurredAt != null &&
        draft.originalOccurredAt != draft.occurredAt) {
      changes.add(
        'Occurrence time corrected from ${draft.originalOccurredAt!.toUtc().toIso8601String()} to ${draft.occurredAt.toUtc().toIso8601String()}.',
      );
    }
    final event = CareEvent(
      id: id,
      wardId: _wardId,
      authorId: _personaId,
      idempotencyKey: draft.idempotencyKey,
      type: draft.type,
      priority: draft.priority,
      residentId: draft.residentId,
      subject: draft.subject,
      place: draft.place,
      notes: draft.notes,
      occurredAt: draft.occurredAt.toUtc(),
      registeredAt: now,
      synchronizedAt: _online ? now : null,
      syncStatus: _online ? SyncStatus.sent : SyncStatus.queued,
      sourceMessageId: draft.sourceMessageId,
      mediaIds: List.of(draft.mediaIds),
      versions: [
        RecordVersion(
          version: 1,
          authorId: _personaId,
          text: changes.join('\n'),
          createdAt: now,
        ),
      ],
    );
    _events.add(event);
    _linkEvent(event);
    if (_online) _route(event);
    _drafts.remove(_draftKey);
    _log(
      _online ? 'Event registered and routed' : 'Event queued offline',
      id,
      jsonEncode(event.toJson()),
    );
    return event;
  });
  void _linkEvent(CareEvent event) {
    _conversations.add(
      Conversation(
        id: event.conversationId,
        wardId: event.wardId,
        title: '${event.type.label} · ${event.residentId ?? event.subject}',
        kind: ConversationKind.event,
        eventId: event.id,
      ),
    );
    _messages.add(
      Message(
        id: _uuid.v4(),
        conversationId: event.conversationId,
        authorId: event.authorId,
        text: event.notes.isEmpty
            ? '${event.type.label} reported at ${event.place}.'
            : event.notes,
        createdAt: event.registeredAt,
        sourceEventIds: [event.id],
      ),
    );
    final eventShift = Shift.at(event.occurredAt, event.wardId);
    var h = _handovers
        .where(
          (h) =>
              h.wardId == event.wardId && h.outgoingShift?.id == eventShift.id,
        )
        .firstOrNull;
    if (h == null) {
      h = Handover(
        id: 'handover-${eventShift.id}',
        wardId: event.wardId,
        shift: eventShift.label,
        outgoingShift: eventShift,
      );
      _handovers.add(h);
    }
    // A signed source snapshot is immutable. New records enter a new draft amendment.
    if (h.status == HandoverStatus.signed ||
        h.status == HandoverStatus.acknowledged) {
      _newHandoverVersion(h, 'New event added to handover sources.');
    }
    h.sourceEventIds.add(event.id);
    _clearHandoverReview(h);
    h.needsDraftUpdate = true;
  }

  void _route(CareEvent event) {
    if (event.priority == Priority.low ||
        _notifications.any((n) => n.eventId == event.id)) {
      return;
    }
    final recipients = _eligible(event).map((s) => s.id).toList();
    _notifications.add(
      CareNotification(
        id: 'notification-${event.id}',
        eventId: event.id,
        wardId: event.wardId,
        recipientIds: recipients,
        createdAt: now,
        sentAt: recipients.isEmpty ? null : now,
        deliveredAt: recipients.isEmpty ? null : now,
        deadline: now.add(
          Duration(
            minutes: event.priority == Priority.high
                ? highTimeoutMinutes
                : mediumReminderMinutes,
          ),
        ),
      ),
    );
  }

  Future<void> _syncPending() async {
    lastSyncError = null;
    for (final event in _events.where((e) => e.syncStatus != SyncStatus.sent)) {
      final author = _staff.firstWhere((s) => s.id == event.authorId);
      if (!author.can(Capability.report, event.wardId) ||
          !author.wardIds.contains(event.wardId)) {
        event.syncStatus = SyncStatus.failed;
        event.syncError =
            'Permission changed. This report was not sent. Contact your coordinator.';
        lastSyncError = event.syncError;
        continue;
      }
      event.syncStatus = SyncStatus.sent;
      event.syncError = null;
      event.synchronizedAt = now;
      _route(event);
      _log('Queued event synchronized', event.id);
    }
  }

  @override
  Future<void> claimEvent(String id) => _mutate(() async {
    final event = eventById(id);
    if (event == null) throw StateError('Event is unavailable.');
    if (event.claimedBy != null) {
      throw StateError('This event has already been taken charge of.');
    }
    if (!canClaim(event)) {
      throw const PermissionDenied(
        'Only an eligible on-duty nurse or coordinator can take charge.',
      );
    }
    await database.customStatement(
      'INSERT INTO event_claims (event_id,staff_id,claimed_at) VALUES (?,?,?)',
      [id, _personaId, now.toIso8601String()],
    );
    event.status = EventStatus.takenCharge;
    event.claimedBy = _personaId;
    event.claimedAt = now;
    for (final n in _notifications.where((n) => n.eventId == id)) {
      n.takenChargeAt = now;
    }
    _log('Event taken charge', id);
  });
  @override
  Future<void> closeEvent(String id, String outcome) => _mutate(() {
    final event = eventById(id);
    if (event == null) throw StateError('Event is unavailable.');
    _require(Capability.claim, event.wardId);
    if (event.claimedBy != _personaId || !currentUser.onDuty) {
      throw const PermissionDenied();
    }
    if (outcome.trim().isEmpty) {
      throw StateError('Add a brief outcome before closing.');
    }
    event.status = EventStatus.closed;
    event.closedBy = _personaId;
    event.closedAt = now;
    event.outcome = outcome.trim();
    for (final n in _notifications.where((n) => n.eventId == id)) {
      n.closedAt = now;
    }
    _log('Event closed', id, outcome);
  });
  Future<void> amendEvent(String id, String note) => _mutate(() {
    final event = eventById(id);
    if (event == null) throw StateError('Event is unavailable.');
    _require(Capability.report, event.wardId);
    if (note.trim().isEmpty) throw StateError('Enter an amendment.');
    event.versions.add(
      RecordVersion(
        version: event.versions.length + 1,
        authorId: _personaId,
        text: note.trim(),
        createdAt: now,
      ),
    );
    _log('Diary amendment appended', id, note);
  });
  Future<void> markNotificationRead(String id) => _mutate(() {
    final n = _notifications.where((n) => n.id == id).firstOrNull;
    if (n == null || !notifications.contains(n)) throw const PermissionDenied();
    n.readAt ??= now;
    _log('Notification read', id);
  });
  Future<void> advanceTime(Duration amount) => _mutate(() {
    if (amount.isNegative) {
      throw StateError('Advance time using a positive duration.');
    }
    _offset += amount;
    _evaluateEscalation();
    _log('Demo clock advanced', _personaId, amount.toString());
  });
  void _evaluateEscalation() {
    for (final n in _notifications) {
      final e = _events.firstWhere((e) => e.id == n.eventId);
      if (e.status != EventStatus.unhandled || now.isBefore(n.deadline)) {
        continue;
      }
      if (e.priority == Priority.medium && n.remindedAt == null) {
        n.remindedAt = now;
        n.deadline = n.createdAt.add(
          Duration(minutes: mediumEscalationMinutes),
        );
        _log('Unhandled reminder recorded', e.id);
      }
      if (!now.isBefore(n.deadline) && n.escalationLevel == 0) {
        n.escalationLevel = 1;
        for (final s in _eligible(e, coordinatorOnly: true)) {
          if (!n.recipientIds.contains(s.id)) n.recipientIds.add(s.id);
        }
        _log('Unhandled event escalated', e.id);
      }
    }
  }

  Future<Message> sendMessage(
    String conversationId,
    String text, {
    String? replyTo,
    String? mediaId,
  }) => _mutate(() {
    final conversation = _conversation(conversationId);
    if (!_online) {
      throw StateError(
        'Messages cannot be sent while offline. Your text is retained in the composer.',
      );
    }
    if (text.trim().isEmpty && mediaId == null) {
      throw StateError('Write a message or attach media.');
    }
    if (replyTo != null) {
      final reply = messageById(replyTo);
      if (reply?.conversationId != conversationId) {
        throw const PermissionDenied();
      }
    }
    if (mediaId != null && mediaById(mediaId) == null) {
      throw StateError('Attachment is unavailable.');
    }
    final message = Message(
      id: _uuid.v4(),
      conversationId: conversationId,
      authorId: _personaId,
      text: text.trim(),
      createdAt: now,
      replyTo: replyTo,
      mediaId: mediaId,
      delivery: 'Sent',
    );
    _messages.add(message);
    _chatDrafts.remove('$_personaId:$conversationId');
    _log('Message appended', message.id, text);
    if (conversation.kind == ConversationKind.assistant) {
      final answer = _answer(text);
      _messages.add(
        Message(
          id: _uuid.v4(),
          conversationId: conversationId,
          authorId: 'assistant',
          text: answer.text,
          createdAt: now,
          sourceEventIds: answer.sourceEventIds,
          ai: true,
          delivery: 'Sent',
        ),
      );
    }
    return message;
  });
  Future<void> markConversationRead(String id) => _mutate(() {
    final messages = messagesFor(id);
    _readCounts['$_personaId:$id'] = messages.length;
    // Reading a conversation never changes event responsibility or alert read status.
    for (final message in messages.where((m) => m.authorId != _personaId)) {
      message.delivery = 'Read';
    }
    _log('Conversation opened', id);
  });
  Future<AssistantAnswer> askAssistant(String text) async {
    _require(Capability.chat, _wardId);
    final answer = _answer(text);
    await sendMessage('assistant-$_personaId-$_wardId', text);
    return answer;
  }

  AssistantAnswer _answer(String text) {
    _require(Capability.chat, _wardId);
    final lower = text.toLowerCase();
    final otherWard = _wards
        .where((w) => !currentUser.can(Capability.chat, w.id))
        .any(
          (w) =>
              lower.contains(w.name.toLowerCase()) ||
              lower.contains(w.id.toLowerCase()),
        );
    final otherResident = _residents
        .where((r) => !currentUser.can(Capability.chat, r.wardId))
        .any(
          (r) =>
              lower.contains(r.id.toLowerCase()) ||
              lower.contains(r.name.toLowerCase()),
        );
    if (otherWard ||
        otherResident ||
        lower.contains('all wards') ||
        lower.contains('private chat')) {
      return const AssistantAnswer(
        'I cannot access records outside your authorized scope.',
        [],
      );
    }
    var selected = events
        .where((e) => e.syncStatus == SyncStatus.sent)
        .toList();
    if (lower.contains('unresolved') || lower.contains('open')) {
      selected = selected.where((e) => e.status != EventStatus.closed).toList();
    }
    final residentPattern = RegExp(
      r'r-\d+',
      caseSensitive: false,
    ).firstMatch(text)?.group(0)?.toUpperCase();
    if (residentPattern != null) {
      selected = selected
          .where((e) => e.residentId == residentPattern)
          .toList();
    }
    if (lower.contains('last shift')) {
      selected = selected
          .where(
            (e) =>
                e.occurredAt.isAfter(now.subtract(const Duration(hours: 16))),
          )
          .toList();
    }
    if (selected.isEmpty) {
      return const AssistantAnswer(
        'No matching authorized records were found. There is not enough evidence to prepare this summary.',
        [],
      );
    }
    final lines = selected
        .take(8)
        .map(
          (e) =>
              '• ${e.type.label} · ${e.residentId ?? e.subject} · ${e.status.label}. ${e.notes}',
        )
        .join('\n');
    return AssistantAnswer(
      'AI draft based on recorded ward events.\n$lines\nReview the linked sources before using this summary. No clinical recommendations are generated.',
      selected.take(8).map((e) => e.id).toList(),
    );
  }

  Future<MediaRecord> saveMedia({
    required List<int> bytes,
    required String mimeType,
    required String label,
    bool synthetic = false,
    int? durationMs,
    String? transcript,
  }) => _mutate(() {
    _require(Capability.care, _wardId);
    if (bytes.isEmpty) throw StateError('The captured attachment is empty.');
    final media = MediaRecord(
      id: _uuid.v4(),
      wardId: _wardId,
      authorId: _personaId,
      mimeType: mimeType,
      base64Data: base64Encode(bytes),
      label: label,
      createdAt: now,
      synthetic: synthetic,
      durationMs: durationMs,
      transcript: transcript,
    );
    _media.add(media);
    _log('Media retained', media.id, media.base64Data);
    return media;
  });
  Future<void> contributeSummary(
    String text, {
    String? expectedHandoverId,
    int? expectedVersion,
  }) => _mutate(() {
    _require(Capability.care, _wardId);
    if (text.trim().isEmpty) {
      throw StateError('Write a summary before adding it.');
    }
    final h = handover;
    _checkHandoverContext(h, expectedHandoverId, expectedVersion);
    final entry = RecordVersion(
      version: h.version,
      authorId: _personaId,
      text: text.trim(),
      createdAt: now,
    );
    if (h.signedBy != null) {
      h.pendingContributions.add(entry);
      _log('Staff update awaiting coordinator review', h.id, text.trim());
      return;
    }
    _clearHandoverReview(h);
    h.needsDraftUpdate = true;
    h.contributions.add(entry);
    _log('Staff summary retained', h.id, text);
  });

  void _checkHandoverContext(Handover h, String? id, int? version) {
    if ((id != null && h.id != id) ||
        (version != null && h.version != version)) {
      throw StateError(
        'The handover changed. Review the current version and try again.',
      );
    }
  }

  Future<void> includePendingHandoverUpdates({
    required String expectedHandoverId,
    required int expectedVersion,
  }) => _mutate(() {
    _require(Capability.coordination, _wardId);
    final h = handover;
    _checkHandoverContext(h, expectedHandoverId, expectedVersion);
    if (h.pendingContributions.isEmpty) {
      throw StateError('There are no staff updates awaiting review.');
    }
    if (h.signedBy != null) {
      _newHandoverVersion(
        h,
        'Staff updates included after coordinator review.',
      );
    }
    final updates = List<RecordVersion>.of(h.pendingContributions);
    h.contributions.addAll(
      updates.map(
        (v) => RecordVersion(
          version: h.version,
          authorId: v.authorId,
          text: v.text,
          createdAt: v.createdAt,
        ),
      ),
    );
    h.draftText = [
      h.draftText ?? '',
      'Additional staff updates',
      ...updates.map((v) => v.text),
    ].where((s) => s.isNotEmpty).join('\n\n');
    h.pendingContributions.clear();
    _clearHandoverReview(h);
    h.needsDraftUpdate = false;
    h.editedBy = _personaId;
    h.editedAt = now;
    _log('Staff updates included in handover draft', h.id);
  });

  /// Opens an existing ward/shift record or prepares its source selection.
  /// Incoming assignments are explicit; presence alone is not an assignment.
  Future<void> selectHandoverShift(Shift shift) => _mutate(() {
    _require(Capability.diary, _wardId);
    if (shift.wardId != _wardId) throw const PermissionDenied();
    var h = _handovers
        .where((h) => h.wardId == _wardId && h.outgoingShift?.id == shift.id)
        .firstOrNull;
    if (h == null) {
      _require(Capability.coordination, _wardId);
      h = Handover(
        id: 'handover-${shift.id}',
        wardId: _wardId,
        shift: shift.label,
        outgoingShift: shift,
        sourceEventIds: events
            .where(
              (e) =>
                  shift.contains(e.occurredAt) ||
                  (e.occurredAt.isBefore(shift.startsAt) &&
                      e.status != EventStatus.closed),
            )
            .map((e) => e.id)
            .toList(),
      );
      _handovers.add(h);
      _log('Handover opened for shift', h.id, shift.id);
    }
    _selectedHandoverId = h.id;
  });

  Future<void> selectHandover(String id) => _mutate(() {
    _require(Capability.diary, _wardId);
    if (!handovers.any((h) => h.id == id)) throw const PermissionDenied();
    _selectedHandoverId = id;
  });

  Future<void> assignHandoverIncomingStaff(List<String> ids) => _mutate(() {
    _require(Capability.coordination, _wardId);
    final h = handover;
    if (h.signedBy != null) {
      throw StateError(
        'Create an amendment before changing the incoming team.',
      );
    }
    final unique = ids.toSet();
    if (unique.any(
      (id) => !_staff.any(
        (s) => s.id == id && s.can(Capability.acknowledge, _wardId),
      ),
    )) {
      throw const PermissionDenied();
    }
    h.incomingStaffIds
      ..clear()
      ..addAll(unique);
    _clearHandoverReview(h);
    _log('Incoming handover team assigned', h.id, unique.join(','));
  });

  String _composeHandoverText(Handover h) {
    final sources = _events.where((e) => h.sourceEventIds.contains(e.id));
    String describe(CareEvent e) =>
        '${e.type.label} · ${e.residentId ?? e.subject} — ${e.status.label}. ${e.notes}';
    final important = sources.where((e) => e.priority != Priority.low);
    final open = sources.where((e) => e.status != EventStatus.closed);
    final notifications = sources.where(
      (e) => e.priority != Priority.low && e.status != EventStatus.closed,
    );
    return [
      'Important reported events',
      important.isEmpty
          ? 'No high- or medium-priority events recorded.'
          : important.map(describe).join('\n\n'),
      '',
      'Open follow-ups',
      open.isEmpty
          ? 'No open follow-ups recorded.'
          : open.map(describe).join('\n\n'),
      '',
      'Unresolved notifications',
      notifications.isEmpty
          ? 'No unresolved notifications recorded.'
          : notifications
                .map(
                  (e) =>
                      '${e.priority.label}: ${e.type.label} · ${e.residentId ?? e.subject} — ${e.status.label}.',
                )
                .join('\n'),
      '',
      'Items to pass to the next shift',
      if (h.contributions.isEmpty)
        'No staff contributions recorded.'
      else
        ...h.contributions.map((c) => c.text),
      ...sources.where((e) => e.priority == Priority.low).map(describe),
    ].join('\n');
  }

  /// Source organization fallback. A future AI adapter supplies generated text
  /// through the same review/save/sign boundary; generation never approves it.
  Future<void> prepareHandoverDraft() => _mutate(() {
    _require(Capability.coordination, _wardId);
    final h = handover;
    if (h.signedBy != null) {
      throw StateError('Create an amendment before preparing a new draft.');
    }
    if (h.draftText?.trim().isNotEmpty ?? false) {
      h.versions.add(
        RecordVersion(
          version: h.version,
          authorId: _personaId,
          text: jsonEncode({'kind': 'draftReplaced', 'narrative': h.draftText}),
          createdAt: now,
        ),
      );
    }
    h.draftText = _composeHandoverText(h);
    h.originalDraftText = h.draftText;
    h.preparedAt = now;
    h.editedBy = null;
    h.editedAt = null;
    h.needsDraftUpdate = false;
    _clearHandoverReview(h);
    _log('Source-based handover draft prepared', h.id, h.draftText ?? '');
  });

  String handoverText([Handover? record]) {
    final h = record ?? handover;
    if (h.draftText != null) return h.draftText!;
    if (h.signedBy != null) {
      // Legacy signed records cannot be reconstructed from mutable live facts.
      return 'The signed narrative is not available for this earlier record. Review its retained history and linked source reports.';
    }
    return '';
  }

  Future<void> saveHandoverDraft(String text) => _mutate(() {
    if (!can(Capability.coordination) && !can(Capability.clinicalValidation)) {
      throw const PermissionDenied();
    }
    final h = handover;
    if (h.signedBy != null) {
      throw StateError(
        'Signed content is preserved. Create an amendment first.',
      );
    }
    if (text.trim().isEmpty) {
      throw StateError('Write the handover before saving.');
    }
    if (h.draftText == text.trim() && !h.needsDraftUpdate) return;
    h.versions.add(
      RecordVersion(
        version: h.version,
        authorId: _personaId,
        text: jsonEncode({
          'kind': 'draftEdited',
          'narrative': h.draftText ?? '',
          'updatedNarrative': text.trim(),
        }),
        createdAt: now,
      ),
    );
    h.draftText = text.trim();
    h.editedBy = _personaId;
    h.editedAt = now;
    h.needsDraftUpdate = false;
    _clearHandoverReview(h);
    _log('Handover draft edited', h.id, text.trim());
  });

  void _clearHandoverReview(Handover h) {
    h.status = HandoverStatus.aiDraft;
    h.reviewedBy = null;
    h.reviewedAt = null;
    h.validatedBy = null;
    h.validatedAt = null;
  }

  Future<void> reviewHandover() => _mutate(() {
    _require(Capability.coordination, _wardId);
    final h = handover;
    if (h.status != HandoverStatus.aiDraft) {
      throw StateError('Only an unsigned draft can be reviewed.');
    }
    if (h.draftText?.trim().isEmpty ?? true) {
      throw StateError(
        'Prepare or write the handover draft before reviewing it.',
      );
    }
    if (h.needsDraftUpdate) {
      throw StateError(
        'Sources or contributions changed. Prepare or edit the draft before reviewing it.',
      );
    }
    h.status = HandoverStatus.reviewed;
    h.reviewedBy = _personaId;
    h.reviewedAt = now;
    _log('Handover reviewed', h.id);
  });
  Future<void> validateHandover() => _mutate(() {
    _require(Capability.clinicalValidation, _wardId);
    final h = handover;
    if (h.status != HandoverStatus.reviewed) {
      throw StateError(
        'The handover must first be reviewed by the coordinator.',
      );
    }
    h.status = HandoverStatus.clinicallyValidated;
    h.validatedBy = _personaId;
    h.validatedAt = now;
    _log('Clinical content validated', h.id);
  });
  Future<void> signHandover() => _mutate(() {
    _require(Capability.signHandover, _wardId);
    final h = handover;
    if (h.status != HandoverStatus.reviewed &&
        h.status != HandoverStatus.clinicallyValidated) {
      throw StateError('Review this handover before signing it.');
    }
    if (h.requiresClinicalValidation && h.validatedBy == null) {
      throw StateError(
        'Clinical content requires physician validation before signing.',
      );
    }
    h.status = HandoverStatus.signed;
    h.signedBy = _personaId;
    h.signedAt = now;
    h.sourceSnapshots
      ..clear()
      ..addAll(
        _events
            .where((e) => h.sourceEventIds.contains(e.id))
            .map(
              (e) => jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
            ),
      );
    h.versions.add(
      RecordVersion(
        version: h.version,
        authorId: _personaId,
        text: jsonEncode({
          'kind': 'signed',
          'narrative': h.draftText,
          'originalDraft': h.originalDraftText,
          'preparedAt': h.preparedAt?.toIso8601String(),
          'reviewedBy': h.reviewedBy,
          'reviewedAt': h.reviewedAt?.toIso8601String(),
          'signedBy': h.signedBy,
          'signedAt': h.signedAt?.toIso8601String(),
          'sourceSnapshots': h.sourceSnapshots,
          'sources': h.sourceEventIds,
          'incomingStaffIds': h.incomingStaffIds,
          'contributions': h.contributions.map((c) => c.toJson()).toList(),
          'validatedBy': h.validatedBy,
        }),
        createdAt: now,
      ),
    );
    _log('Outgoing handover signed', h.id, 'Version ${h.version}');
  });
  Future<void> acknowledgeHandover({
    int? expectedVersion,
    String? expectedHandoverId,
  }) => _mutate(() {
    _require(Capability.acknowledge, _wardId);
    final h = handover;
    if ((expectedVersion != null && expectedVersion != h.version) ||
        (expectedHandoverId != null && expectedHandoverId != h.id)) {
      throw StateError(
        'The handover version changed. Review the current signed version before acknowledging it.',
      );
    }
    if (h.signedBy == null || !h.incomingStaffIds.contains(_personaId)) {
      throw const PermissionDenied(
        'Only assigned incoming staff can acknowledge a signed handover.',
      );
    }
    h.acknowledgements.putIfAbsent(_personaId, () => now.toIso8601String());
    if (h.incomingStaffIds.every(h.acknowledgements.containsKey)) {
      h.status = HandoverStatus.acknowledged;
    }
    _log('Incoming handover acknowledged', h.id, 'Version ${h.version}');
  });
  void _newHandoverVersion(Handover h, String amendment) {
    h.versions.add(
      RecordVersion(
        version: h.version,
        authorId: _personaId,
        text: jsonEncode({
          'kind': 'amendment',
          'amendment': amendment,
          'narrative': h.draftText,
          'originalDraft': h.originalDraftText,
          'sourceSnapshots': h.sourceSnapshots,
          'reviewedBy': h.reviewedBy,
          'reviewedAt': h.reviewedAt?.toIso8601String(),
          'signedBy': h.signedBy,
          'signedAt': h.signedAt?.toIso8601String(),
          'validatedBy': h.validatedBy,
          'validatedAt': h.validatedAt?.toIso8601String(),
          'acknowledgements': Map.of(h.acknowledgements),
          'sources': List.of(h.sourceEventIds),
          'incomingStaffIds': List.of(h.incomingStaffIds),
          'contributions': h.contributions.map((v) => v.toJson()).toList(),
        }),
        createdAt: now,
      ),
    );
    h.version++;
    h.status = HandoverStatus.aiDraft;
    h.reviewedBy = null;
    h.reviewedAt = null;
    h.validatedBy = null;
    h.validatedAt = null;
    h.signedBy = null;
    h.signedAt = null;
    h.acknowledgements.clear();
    h.sourceSnapshots.clear();
  }

  Future<void> amendHandover(String text) => _mutate(() {
    _require(Capability.coordination, _wardId);
    if (text.trim().isEmpty) throw StateError('Enter an amendment.');
    final h = handover;
    if (h.signedBy == null) {
      throw StateError(
        'Only a signed handover needs an amendment. Edit the draft instead.',
      );
    }
    _newHandoverVersion(h, text.trim());
    h.draftText = '${h.draftText ?? ''}\n\nAmendment\n${text.trim()}'.trim();
    h.editedBy = _personaId;
    h.editedAt = now;
    h.needsDraftUpdate = false;
    h.contributions.add(
      RecordVersion(
        version: h.version,
        authorId: _personaId,
        text: text.trim(),
        createdAt: now,
      ),
    );
    _log('Handover amendment appended', h.id, text);
  });
  Future<OcrItem> createDocumentFromMedia(String mediaId, {String? title}) =>
      _mutate(() {
        _require(Capability.care, _wardId);
        final media = mediaById(mediaId);
        if (media == null ||
            media.wardId != _wardId ||
            !media.mimeType.startsWith('image/')) {
          throw const PermissionDenied('Choose an image in the current ward.');
        }
        final item = OcrItem(
          id: _uuid.v4(),
          wardId: _wardId,
          originalText: '',
          title: title?.trim().isNotEmpty == true ? title!.trim() : media.label,
          sourceMediaId: media.id,
          sourceFingerprint: sha256.convert(media.bytes).toString(),
          createdAt: now,
        );
        _ocr.insert(0, item);
        _log(
          'Document source retained; extraction pending',
          item.id,
          item.sourceFingerprint!,
        );
        return item;
      });

  Future<void> confirmOcr(String id, String text) => _mutate(() {
    _require(Capability.care, _wardId);
    final o = _ocr.where((o) => o.id == id).firstOrNull;
    if (o == null) throw const PermissionDenied();
    _require(Capability.care, o.wardId);
    if (text.trim().isEmpty) {
      throw StateError('Review the extracted text before confirming.');
    }
    if (o.reviewedAt != null) {
      throw StateError(
        'This extraction was already confirmed. The original and reviewed text are preserved.',
      );
    }
    o.correctedText = text.trim();
    o.reviewedBy = _personaId;
    o.reviewedAt = now;
    o.versions.add(
      RecordVersion(
        version: 1,
        authorId: _personaId,
        text: text.trim(),
        createdAt: now,
      ),
    );
    _log('OCR text reviewed', id, text);
  });
  Future<void> appendOcrCorrection(String id, String text) => _mutate(() {
    _require(Capability.care, _wardId);
    final item = _ocr.where((o) => o.id == id).firstOrNull;
    if (item == null) throw const PermissionDenied();
    _require(Capability.care, item.wardId);
    if (!item.isReviewed) {
      throw StateError(
        'Confirm the first transcription before adding a correction.',
      );
    }
    if (text.trim().isEmpty || text.trim() == item.correctedText) {
      throw StateError('Enter a correction before saving a new version.');
    }
    // Older saved documents may predate explicit version records.
    if (item.versions.isEmpty) {
      item.versions.add(
        RecordVersion(
          version: 1,
          authorId: item.reviewedBy!,
          text: item.correctedText ?? item.originalText,
          createdAt: item.reviewedAt!,
        ),
      );
    }
    item.versions.add(
      RecordVersion(
        version: item.versions.last.version + 1,
        authorId: _personaId,
        text: text.trim(),
        createdAt: now,
      ),
    );
    item.correctedText = text.trim();
    item.reviewedBy = _personaId;
    item.reviewedAt = now;
    _log('Document correction appended', id, text);
  });
  Map<String, int> aggregateCounts({String? wardId, DateTime? date}) {
    _require(Capability.management);
    final ids = wardId == null
        ? currentUser.assignments
              .where(
                (a) =>
                    roleCapabilities[a.role]?.contains(Capability.management) ??
                    false,
              )
              .map((a) => a.wardId)
              .toSet()
              .toList()
        : [wardId];
    if (ids.any((id) => !currentUser.can(Capability.management, id))) {
      throw const PermissionDenied();
    }
    final localDate = date == null ? null : FacilityTime.local(date);
    final selected = _events.where((e) {
      if (!ids.contains(e.wardId) || e.syncStatus != SyncStatus.sent) {
        return false;
      }
      if (localDate == null) return true;
      final occurred = FacilityTime.local(e.occurredAt);
      return occurred.year == localDate.year &&
          occurred.month == localDate.month &&
          occurred.day == localDate.day;
    }).toList();
    return {
      'events': selected.length,
      'unhandled': selected
          .where((e) => e.status == EventStatus.unhandled)
          .length,
      'high': selected.where((e) => e.priority == Priority.high).length,
      'closed': selected.where((e) => e.status == EventStatus.closed).length,
      'onDuty': _staff
          .where((s) => s.onDuty && s.wardIds.any(ids.contains))
          .length,
    };
  }

  Future<void> reset() => _mutate(() async {
    await database.customStatement('DELETE FROM event_keys');
    await database.customStatement('DELETE FROM event_claims');
    _seed();
    for (final e in _events) {
      await database.customStatement('INSERT INTO event_keys VALUES (?, ?)', [
        e.idempotencyKey,
        e.id,
      ]);
      if (e.claimedBy != null) {
        await database.customStatement(
          'INSERT INTO event_claims VALUES (?, ?, ?)',
          [e.id, e.claimedBy, e.claimedAt!.toIso8601String()],
        );
      }
    }
  });
  void _ensureAssistant() {
    if (!can(Capability.chat)) return;
    final id = 'assistant-$_personaId-$_wardId';
    if (!_conversations.any((c) => c.id == id)) {
      _conversations.add(
        Conversation(
          id: id,
          wardId: _wardId,
          title: 'RSA Assistant',
          kind: ConversationKind.assistant,
          ownerId: _personaId,
        ),
      );
    }
  }

  Map<String, dynamic> _serialize() => {
    'personaId': _personaId,
    'wardId': _wardId,
    'online': _online,
    'offset': _offset.inMilliseconds,
    'wards': _wards.map((x) => x.toJson()).toList(),
    'staff': _staff.map((x) => x.toJson()).toList(),
    'residents': _residents.map((x) => x.toJson()).toList(),
    'events': _events.map((x) => x.toJson()).toList(),
    'notifications': _notifications.map((x) => x.toJson()).toList(),
    'conversations': _conversations.map((x) => x.toJson()).toList(),
    'messages': _messages.map((x) => x.toJson()).toList(),
    'handovers': _handovers.map((x) => x.toJson()).toList(),
    'ocr': _ocr.map((x) => x.toJson()).toList(),
    'audit': _auditEntries.map((x) => x.toJson()).toList(),
    'media': _media.map((x) => x.toJson()).toList(),
    'drafts': _drafts.map((key, value) => MapEntry(key, value.toJson())),
    'readCounts': _readCounts,
    'openedEventConversations': _openedEventConversations.toList(),
    'chatDrafts': _chatDrafts,
    'highTimeoutMinutes': highTimeoutMinutes,
    'mediumReminderMinutes': mediumReminderMinutes,
    'mediumEscalationMinutes': mediumEscalationMinutes,
  };
  void _restore(Map<String, dynamic> j) {
    _personaId = j['personaId'];
    _wardId = j['wardId'];
    _online = j['online'];
    _offset = Duration(milliseconds: j['offset']);
    _wards = (j['wards'] as List)
        .map((x) => Ward.fromJson(objectMap(x)))
        .toList();
    _staff = (j['staff'] as List)
        .map((x) => StaffMember.fromJson(objectMap(x)))
        .toList();
    _residents = (j['residents'] as List)
        .map((x) => Resident.fromJson(objectMap(x)))
        .toList();
    _events = (j['events'] as List)
        .map((x) => CareEvent.fromJson(objectMap(x)))
        .toList();
    _notifications = (j['notifications'] as List)
        .map((x) => CareNotification.fromJson(objectMap(x)))
        .toList();
    _conversations = (j['conversations'] as List)
        .map((x) => Conversation.fromJson(objectMap(x)))
        .toList();
    _messages = (j['messages'] as List)
        .map((x) => Message.fromJson(objectMap(x)))
        .toList();
    _handovers = (j['handovers'] as List)
        .map((x) => Handover.fromJson(objectMap(x)))
        .toList();
    _ocr = (j['ocr'] as List)
        .map((x) => OcrItem.fromJson(objectMap(x)))
        .toList();
    _auditEntries = (j['audit'] as List)
        .map((x) => AuditEntry.fromJson(objectMap(x)))
        .toList();
    _media = (j['media'] as List)
        .map((x) => MediaRecord.fromJson(objectMap(x)))
        .toList();
    _drafts = objectMap(
      j['drafts'],
    ).map((key, value) => MapEntry(key, EventDraft.fromJson(objectMap(value))));
    _readCounts
      ..clear()
      ..addAll(Map<String, int>.from(j['readCounts'] ?? {}));
    _openedEventConversations
      ..clear()
      ..addAll(strings(j['openedEventConversations']));
    _chatDrafts = objectMap(
      j['chatDrafts'] ?? {},
    ).map((key, value) => MapEntry(key, objectMap(value)));
    highTimeoutMinutes = j['highTimeoutMinutes'] ?? 2;
    mediumReminderMinutes = j['mediumReminderMinutes'] ?? 5;
    mediumEscalationMinutes = j['mediumEscalationMinutes'] ?? 10;
  }

  void _seed() {
    _personaId = 'nurse-1';
    _wardId = 'oak';
    _online = true;
    _offset = Duration.zero;
    _wards = [
      const Ward('oak', 'Oak Ward'),
      const Ward('willow', 'Willow Ward'),
    ];
    _staff = [
      StaffMember(
        id: 'nurse-1',
        name: 'Emily Carter',
        role: Role.nurse,
        wardIds: ['oak'],
        skills: ['General care', 'Nursing', 'Wound care'],
      ),
      StaffMember(
        id: 'assistant-1',
        name: 'James Wilson',
        role: Role.assistant,
        wardIds: ['oak'],
        skills: ['General care', 'Mobility'],
      ),
      StaffMember(
        id: 'technician-1',
        name: 'Alex Morgan',
        role: Role.technician,
        wardIds: ['oak'],
        skills: ['Equipment', 'Safety'],
      ),
      StaffMember(
        id: 'physician-1',
        name: 'Dr. Olivia Reed',
        role: Role.physician,
        wardIds: ['oak'],
        skills: ['Clinical validation'],
      ),
      StaffMember(
        id: 'coordinator-1',
        name: 'Sarah Mitchell',
        role: Role.coordinator,
        wardIds: ['oak'],
        skills: ['Nursing', 'Shift coordination'],
      ),
      StaffMember(
        id: 'management-1',
        name: 'Daniel Brooks',
        role: Role.management,
        wardIds: ['oak', 'willow'],
        skills: ['Operations'],
      ),
      StaffMember(
        id: 'admin-1',
        name: 'Taylor Quinn',
        role: Role.administrator,
        wardIds: ['oak', 'willow'],
        skills: ['Systems'],
      ),
      StaffMember(
        id: 'nurse-2',
        name: 'Mia Thompson',
        role: Role.nurse,
        wardIds: ['oak'],
        onDuty: false,
        skills: ['Nursing'],
      ),
      StaffMember(
        id: 'nurse-3',
        name: 'Noah Parker',
        role: Role.nurse,
        wardIds: ['oak'],
        availability: Availability.busy,
        skills: ['Nursing'],
      ),
      StaffMember(
        id: 'nurse-4',
        name: 'Amelia Hayes',
        role: Role.nurse,
        wardIds: ['oak'],
        availability: Availability.onBreak,
        skills: ['Nursing'],
      ),
      StaffMember(
        id: 'willow-nurse',
        name: 'Lucas Bennett',
        role: Role.nurse,
        wardIds: ['willow'],
        skills: ['Nursing'],
      ),
    ];
    for (final person in _staff.where(
      (s) => s.onDuty && s.can(Capability.care),
    )) {
      person.checkedInAt = Shift.at(now, person.wardIds.first).startsAt;
    }
    _residents = [
      const Resident(
        id: 'R-014',
        wardId: 'oak',
        name: 'Margaret W.',
        room: 'Room 104',
      ),
      const Resident(
        id: 'R-022',
        wardId: 'oak',
        name: 'Arthur B.',
        room: 'Room 108',
      ),
      const Resident(
        id: 'R-031',
        wardId: 'oak',
        name: 'Eleanor S.',
        room: 'Room 112',
      ),
      const Resident(
        id: 'R-047',
        wardId: 'oak',
        name: 'Henry C.',
        room: 'Room 116',
      ),
      const Resident(
        id: 'R-201',
        wardId: 'willow',
        name: 'Grace P.',
        room: 'Room 201',
      ),
    ];
    final current = now;
    _events = [
      CareEvent(
        id: 'event-fall',
        wardId: 'oak',
        authorId: 'assistant-1',
        idempotencyKey: 'seed-fall',
        type: EventType.fall,
        priority: Priority.high,
        residentId: 'R-014',
        place: 'Bathroom',
        notes:
            'Resident found seated on the bathroom floor. Nurse requested to attend.',
        occurredAt: current.subtract(const Duration(minutes: 8)),
        registeredAt: current.subtract(const Duration(minutes: 7)),
        synchronizedAt: current.subtract(const Duration(minutes: 7)),
      ),
      CareEvent(
        id: 'event-skin',
        wardId: 'oak',
        authorId: 'assistant-1',
        idempotencyKey: 'seed-skin',
        type: EventType.skin,
        priority: Priority.medium,
        residentId: 'R-022',
        place: 'Room 108',
        notes: 'New redness reported on the left heel during morning care.',
        occurredAt: current.subtract(const Duration(minutes: 38)),
        registeredAt: current.subtract(const Duration(minutes: 37)),
        synchronizedAt: current.subtract(const Duration(minutes: 37)),
        status: EventStatus.takenCharge,
        claimedBy: 'nurse-1',
        claimedAt: current.subtract(const Duration(minutes: 30)),
      ),
      CareEvent(
        id: 'event-hygiene',
        wardId: 'oak',
        authorId: 'assistant-1',
        idempotencyKey: 'seed-hygiene',
        type: EventType.hygiene,
        priority: Priority.low,
        residentId: 'R-031',
        place: 'Room 112',
        notes: 'Assistance with personal hygiene recorded by the morning team.',
        occurredAt: current.subtract(const Duration(hours: 1)),
        registeredAt: current.subtract(const Duration(minutes: 59)),
        synchronizedAt: current.subtract(const Duration(minutes: 59)),
      ),
      CareEvent(
        id: 'event-refusal',
        wardId: 'oak',
        authorId: 'nurse-1',
        idempotencyKey: 'seed-refusal',
        type: EventType.refusal,
        priority: Priority.medium,
        residentId: 'R-047',
        place: 'Dining room',
        notes: 'Breakfast declined. Report passed to the nurse for follow-up.',
        occurredAt: current.subtract(const Duration(hours: 2)),
        registeredAt: current.subtract(const Duration(hours: 2)),
        synchronizedAt: current.subtract(const Duration(hours: 2)),
        status: EventStatus.closed,
        claimedBy: 'nurse-1',
        claimedAt: current.subtract(const Duration(minutes: 110)),
        closedBy: 'nurse-1',
        closedAt: current.subtract(const Duration(minutes: 90)),
        outcome: 'Follow-up recorded in the ward diary.',
      ),
      CareEvent(
        id: 'willow-event',
        wardId: 'willow',
        authorId: 'willow-nurse',
        idempotencyKey: 'seed-willow',
        type: EventType.safety,
        priority: Priority.medium,
        subject: 'Equipment',
        place: 'Corridor',
        notes: 'Wheelchair brake fault reported for equipment review.',
        occurredAt: current.subtract(const Duration(minutes: 40)),
        registeredAt: current.subtract(const Duration(minutes: 39)),
        synchronizedAt: current.subtract(const Duration(minutes: 39)),
      ),
    ];
    for (final e in _events) {
      e.versions.add(
        RecordVersion(
          version: 1,
          authorId: e.authorId,
          text: e.notes,
          createdAt: e.registeredAt,
        ),
      );
    }
    _notifications = [];
    for (final e in _events) {
      _route(e);
    }
    for (final n in _notifications) {
      final e = _events.firstWhere((e) => e.id == n.eventId);
      n.takenChargeAt = e.claimedAt;
      n.closedAt = e.closedAt;
    }
    _conversations = [
      Conversation(
        id: 'team-oak',
        wardId: 'oak',
        title: 'Oak Ward team',
        kind: ConversationKind.ward,
      ),
      Conversation(
        id: 'team-willow',
        wardId: 'willow',
        title: 'Willow Ward team',
        kind: ConversationKind.ward,
      ),
      Conversation(
        id: 'direct-emily-sarah',
        wardId: 'oak',
        title: 'Sarah Mitchell',
        kind: ConversationKind.direct,
        memberIds: ['nurse-1', 'coordinator-1'],
      ),
      Conversation(
        id: 'direct-james-emily',
        wardId: 'oak',
        title: 'James Wilson',
        kind: ConversationKind.direct,
        memberIds: ['nurse-1', 'assistant-1'],
      ),
      for (final e in _events)
        Conversation(
          id: e.conversationId,
          wardId: e.wardId,
          title: '${e.type.label} · ${e.residentId ?? e.subject}',
          kind: ConversationKind.event,
          eventId: e.id,
        ),
    ];
    _messages = [
      Message(
        id: 'message-1',
        conversationId: 'team-oak',
        authorId: 'coordinator-1',
        text:
            'Good morning, team. Please record updates in the ward diary before handover.',
        createdAt: current.subtract(const Duration(hours: 1, minutes: 10)),
        delivery: 'Delivered',
      ),
      Message(
        id: 'message-2',
        conversationId: 'team-oak',
        authorId: 'assistant-1',
        text:
            'Morning personal care is underway. I will report any changes here.',
        createdAt: current.subtract(const Duration(minutes: 56)),
        delivery: 'Delivered',
      ),
      Message(
        id: 'message-3',
        conversationId: 'team-oak',
        authorId: 'nurse-1',
        text: 'Thank you. I am available in Oak Ward for the morning shift.',
        createdAt: current.subtract(const Duration(minutes: 52)),
        delivery: 'Read',
      ),
      Message(
        id: 'message-4',
        conversationId: 'direct-emily-sarah',
        authorId: 'coordinator-1',
        text: 'Please review the open items before the next handover.',
        createdAt: current.subtract(const Duration(minutes: 20)),
        delivery: 'Delivered',
      ),
      Message(
        id: 'message-5',
        conversationId: 'direct-james-emily',
        authorId: 'assistant-1',
        text:
            'Could you check the new skin report for R-022? It is linked in the diary.',
        createdAt: current.subtract(const Duration(minutes: 31)),
        delivery: 'Delivered',
      ),
      for (final e in _events)
        Message(
          id: 'message-${e.id}',
          conversationId: e.conversationId,
          authorId: e.authorId,
          text: e.notes,
          createdAt: e.registeredAt,
          sourceEventIds: [e.id],
          delivery: 'Delivered',
        ),
    ];
    _handovers = [
      Handover(
        id: 'handover-oak',
        wardId: 'oak',
        shift: Shift.at(current, 'oak').label,
        outgoingShift: Shift.at(current, 'oak'),
        sourceEventIds: _events
            .where((e) => e.wardId == 'oak')
            .map((e) => e.id)
            .toList(),
        incomingStaffIds: ['nurse-1', 'assistant-1', 'nurse-2'],
        contributions: [
          RecordVersion(
            version: 1,
            authorId: 'assistant-1',
            text:
                'Morning care updates are recorded in the linked diary. The fall report remains open for the next team.',
            createdAt: current.subtract(const Duration(minutes: 15)),
          ),
        ],
        status: HandoverStatus.signed,
        reviewedBy: 'coordinator-1',
        reviewedAt: current.subtract(const Duration(minutes: 14)),
        signedBy: 'coordinator-1',
        signedAt: current.subtract(const Duration(minutes: 12)),
        versions: [
          RecordVersion(
            version: 1,
            authorId: 'coordinator-1',
            text:
                'Signed synthetic handover. Source events: event-fall, event-skin, event-hygiene, event-refusal.',
            createdAt: current.subtract(const Duration(minutes: 12)),
          ),
        ],
      ),
      Handover(
        id: 'handover-willow',
        wardId: 'willow',
        shift: Shift.at(current, 'willow').label,
        outgoingShift: Shift.at(current, 'willow'),
        sourceEventIds: ['willow-event'],
        incomingStaffIds: ['willow-nurse'],
      ),
    ];
    for (final h in _handovers) {
      h.draftText = _composeHandoverText(h);
      h.originalDraftText = h.draftText;
      h.preparedAt = current.subtract(const Duration(minutes: 16));
      if (h.signedBy != null) {
        h.sourceSnapshots.addAll(
          _events
              .where((e) => h.sourceEventIds.contains(e.id))
              .map(
                (e) =>
                    jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
              ),
        );
        h.versions
          ..clear()
          ..add(
            RecordVersion(
              version: h.version,
              authorId: h.signedBy!,
              createdAt: h.signedAt!,
              text: jsonEncode({
                'kind': 'signed',
                'narrative': h.draftText,
                'originalDraft': h.originalDraftText,
                'sourceSnapshots': h.sourceSnapshots,
                'sources': h.sourceEventIds,
                'contributions': h.contributions
                    .map((c) => c.toJson())
                    .toList(),
                'signedBy': h.signedBy,
                'signedAt': h.signedAt!.toIso8601String(),
                'reviewedBy': h.reviewedBy,
                'reviewedAt': h.reviewedAt?.toIso8601String(),
              }),
            ),
          );
      }
    }
    _ocr = [
      OcrItem(
        id: 'ocr-oak',
        wardId: 'oak',
        originalText:
            'Equipment check · 0[8?]:30\nWheelchair 04 · brake inspection requested.\nTime is uncertain. Review required.',
        uncertainSegments: ['0[8?]:30'],
      ),
    ];
    _media = [];
    _drafts = {};
    _chatDrafts = {};
    _readCounts.clear();
    _openedEventConversations.clear();
    _auditEntries = [];
    _ensureAssistant();
    _log('Synthetic data initialized', 'demo');
  }

  Future<void> close() => _closeFuture ??= _closeResources();
  Future<void> _closeResources() async {
    await _tail;
    await _updates.close();
    await database.close();
    dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
