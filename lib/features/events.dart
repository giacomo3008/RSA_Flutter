import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/media.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/repository.dart';
import '../shared/media_capture.dart';
import '../shared/ui.dart';

const _teal = Color(0xFF167D8D);
const _slate = Color(0xFF526477);
const _red = Color(0xFFB34242);
const _amber = Color(0xFF946118);
const _green = Color(0xFF387663);

String _typeKey(EventType type) => switch (type) {
  EventType.fall => 'typeFall',
  EventType.health => 'typeHealth',
  EventType.wandering => 'typeWandering',
  EventType.agitation => 'typeAgitation',
  EventType.refusal => 'typeRefusal',
  EventType.skin => 'typeSkinWound',
  EventType.safety => 'typeSafety',
  EventType.hygiene => 'typeHygiene',
};

IconData eventTypeIcon(EventType type) => eventIcon(type);

String _priorityKey(Priority value) => switch (value) {
  Priority.high => 'priorityHigh',
  Priority.medium => 'priorityMedium',
  Priority.low => 'priorityLow',
};
Color _priorityColor(Priority value) => switch (value) {
  Priority.high => _red,
  Priority.medium => _amber,
  Priority.low => _green,
};
IconData _priorityIcon(Priority value) => switch (value) {
  Priority.high => Icons.priority_high_rounded,
  Priority.medium => Icons.remove_rounded,
  Priority.low => Icons.arrow_downward_rounded,
};

String _statusKey(CareEvent event) {
  if (event.syncStatus == SyncStatus.queued) return 'queuedLabel';
  return switch (event.status) {
    EventStatus.unhandled => 'notTakenCharge',
    EventStatus.takenCharge => 'takenCharge',
    EventStatus.closed => 'closedLabel',
  };
}

String _subject(RsaRepository repo, CareEvent event) =>
    repo.residentById(event.residentId ?? '')?.name ?? event.subject;

MediaPayload _mediaPayload(MediaRecord record) => MediaPayload(
  kind: record.mimeType.startsWith('image/') ? 'photo' : 'audio',
  bytes: Uint8List.fromList(record.bytes),
  mimeType: record.mimeType,
  name: record.label,
  synthetic: record.synthetic,
  durationMs: record.durationMs,
  transcript: record.transcript,
);

class ReportScreen extends ConsumerStatefulWidget {
  final String? sourceMessageId;
  final EventDraft? initialDraft;
  const ReportScreen({super.key, this.sourceMessageId, this.initialDraft});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late final RsaRepository _repo;
  late EventDraft _draft;
  late final TextEditingController _notes;
  late final TextEditingController _subjectController;
  late final TextEditingController _place;
  late final DateTime _openedAt;
  Timer? _saveTimer;
  bool _other = false;
  bool _sending = false;
  bool _dirty = false;
  bool _allowPop = false;
  bool _saveFailed = false;
  bool _draftSaved = false;
  int _draftRevision = 0;
  bool _savingMedia = false;
  CareEvent? _result;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(rsaRepositoryProvider);
    _openedAt = _repo.now;
    final saved = _repo.draft;
    _draft = widget.initialDraft != null
        ? EventDraft.fromJson(widget.initialDraft!.toJson())
        : saved != null && widget.sourceMessageId == null
        ? EventDraft.fromJson(saved.toJson())
        : EventDraft(
            idempotencyKey: widget.sourceMessageId == null
                ? 'report-${_repo.currentUser.id}-${DateTime.now().microsecondsSinceEpoch}'
                : 'message-${widget.sourceMessageId}',
            occurredAt: _openedAt,
            sourceMessageId: widget.sourceMessageId,
          );
    if (widget.sourceMessageId != null) {
      final message = _repo.messageById(widget.sourceMessageId!);
      _draft.notes = message?.text ?? '';
    }
    _other = _draft.subject.isNotEmpty && _draft.residentId == null;
    _notes = TextEditingController(text: _draft.notes);
    _subjectController = TextEditingController(text: _draft.subject);
    _place = TextEditingController(text: _draft.place);
    _dirty =
        saved != null ||
        widget.sourceMessageId != null ||
        widget.initialDraft != null;
    _draftSaved =
        saved != null &&
        widget.initialDraft == null &&
        widget.sourceMessageId == null;
    _notes.addListener(_textChanged);
    _subjectController.addListener(_textChanged);
    _place.addListener(_textChanged);
  }

  void _textChanged() {
    _draft.notes = _notes.text;
    _draft.subject = _subjectController.text;
    _draft.place = _place.text;
    _changed();
  }

  void _changed() {
    if (!mounted || _result != null) return;
    setState(() {
      _dirty = true;
      _draftSaved = false;
      _draftRevision++;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _persist);
  }

  Future<bool> _persist() async {
    final revision = _draftRevision;
    try {
      await _repo.saveDraft(EventDraft.fromJson(_draft.toJson()));
      if (mounted) {
        setState(() {
          _saveFailed = false;
          _draftSaved = revision == _draftRevision;
        });
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
      return false;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _notes.dispose();
    _subjectController.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_sending) return;
    if (!_dirty || _result != null) {
      _exit();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'discardDraftTitle')),
        content: Text(tr(context, 'discardDraftBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(tr(context, 'discardDraft')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'keepEditing')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(tr(context, 'leaveWithDraft')),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    _saveTimer?.cancel();
    if (action == 'discard') {
      await _repo.saveDraft(null);
    } else if (!await _persist()) {
      return;
    }
    if (mounted) _exit();
  }

  void _exit() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    });
  }

  Future<void> _pickResident() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ResidentPicker(residents: _repo.residents),
    );
    if (result == null || !mounted) return;
    if (result == '__other') {
      _other = true;
      _draft.residentId = null;
    } else {
      _other = false;
      _draft.residentId = result;
      _subjectController.clear();
      _place.text = _repo.residentById(result)?.room ?? '';
    }
    _changed();
  }

  Future<void> _pickTime() async {
    final location = tz.getLocation('Europe/Rome');
    final local = tz.TZDateTime.from(_draft.occurredAt, location);
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: local.subtract(const Duration(days: 365)),
      lastDate: tz.TZDateTime.from(
        _repo.now,
        location,
      ).add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
    );
    if (time == null || !mounted) return;
    _draft.originalOccurredAt ??= _draft.occurredAt;
    _draft.occurredAt = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();
    _changed();
  }

  Future<void> _attach(MediaPayload payload) async {
    setState(() => _savingMedia = true);
    try {
      final media = await _repo.saveMedia(
        bytes: payload.bytes,
        mimeType: payload.mimeType,
        label: payload.name,
        synthetic: payload.synthetic,
        durationMs: payload.durationMs,
        transcript: payload.transcript,
      );
      if (!mounted) return;
      _draft.mediaIds.add(media.id);
      _changed();
      await _persist();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _savingMedia = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _savingMedia) return;
    if (_draft.residentId == null && _draft.subject.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, 'missingResident'))));
      return;
    }
    _saveTimer?.cancel();
    setState(() => _sending = true);
    try {
      final event = await _repo.reportEvent(
        EventDraft.fromJson(_draft.toJson()),
      );
      await _repo.saveDraft(null);
      if (mounted) setState(() => _result = event);
    } catch (error) {
      await _persist();
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(rsaRepositoryProvider);
    final resident = repo.residentById(_draft.residentId ?? '');
    return PopScope(
      canPop: _allowPop || !_dirty || _result != null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _leave,
            icon: const Icon(Icons.close_rounded),
            tooltip: tr(context, 'backToWorkspace'),
          ),
          title: Text(tr(context, 'reportEventTitle')),
          actions: [
            if (_dirty && _result == null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Tooltip(
                  message: tr(
                    context,
                    _saveFailed
                        ? 'reportNotSaved'
                        : _draftSaved
                        ? 'reportSaved'
                        : 'savingDraft',
                  ),
                  child: Icon(
                    _saveFailed
                        ? Icons.cloud_off_outlined
                        : _draftSaved
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_upload_outlined,
                    size: 20,
                    color: _saveFailed ? _red : _green,
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _result != null
            ? null
            : SafeArea(
                minimum: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Center(
                  heightFactor: 1,
                  child: SizedBox(
                    width: 740,
                    child: FilledButton.icon(
                      key: const Key('report-submit'),
                      onPressed: _sending || _savingMedia ? null : _send,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(
                        tr(context, _sending ? 'sendingEvent' : 'sendEvent'),
                      ),
                    ),
                  ),
                ),
              ),
        body: _result != null
            ? _ReportResult(event: _result!, onDone: _exit)
            : SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 780,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        Text(
                          tr(context, 'reportEventSubtitle'),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: _slate),
                        ),
                        const SizedBox(height: 16),
                        if ((_draft.sourceMessageId != null)) ...[
                          _InfoBanner(
                            icon: Icons.forum_outlined,
                            text: tr(context, 'fromMessageLabel'),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _FormLabel(tr(context, 'eventTypeLabel')),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final count = constraints.maxWidth < 320 ? 2 : 4;
                            final width =
                                (constraints.maxWidth - (count - 1) * 8) /
                                count;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: EventType.values.map((type) {
                                final selected = _draft.type == type;
                                return SizedBox(
                                  width: width,
                                  child: Semantics(
                                    selected: selected,
                                    button: true,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _draft.type = type;
                                        _draft.priority = type.defaultPriority;
                                        _changed();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: selected
                                            ? _teal
                                            : _slate,
                                        backgroundColor: selected
                                            ? const Color(0xFFEAF5F6)
                                            : Colors.white,
                                        side: BorderSide(
                                          color: selected
                                              ? _teal
                                              : const Color(0xFFDFE5E9),
                                          width: selected ? 1.5 : 1,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                          horizontal: 4,
                                        ),
                                        minimumSize: const Size(48, 82),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(eventTypeIcon(type), size: 25),
                                          const SizedBox(height: 8),
                                          Text(
                                            tr(context, _typeKey(type)),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _FormLabel(tr(context, 'priorityLabel')),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: Priority.values.reversed
                              .map(
                                (priority) => ChoiceChip(
                                  selected: _draft.priority == priority,
                                  avatar: Icon(
                                    _priorityIcon(priority),
                                    size: 18,
                                    color: _priorityColor(priority),
                                  ),
                                  label: Text(
                                    tr(context, _priorityKey(priority)),
                                  ),
                                  onSelected: (_) {
                                    _draft.priority = priority;
                                    _changed();
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(context, switch (_draft.priority) {
                            Priority.high => 'highPriorityNote',
                            Priority.medium => 'mediumPriorityNote',
                            Priority.low => 'lowPriorityNote',
                          }),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: _slate),
                        ),
                        const SizedBox(height: 24),
                        _FormLabel(tr(context, 'residentLabel')),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const Key('resident-picker'),
                          onPressed: _pickResident,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                            foregroundColor: const Color(0xFF24384A),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _other
                                      ? tr(context, 'residentOther')
                                      : resident == null
                                      ? tr(context, 'selectResident')
                                      : '${resident.name} · ${resident.room}',
                                  textAlign: TextAlign.start,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                        if (_other) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _subjectController,
                            decoration: InputDecoration(
                              labelText: tr(context, 'subjectLabel'),
                              hintText: tr(context, 'subjectHint'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextField(
                          controller: _place,
                          decoration: InputDecoration(
                            labelText: tr(context, 'placeLabel'),
                            hintText: tr(context, 'placeHint'),
                            prefixIcon: const Icon(Icons.place_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children:
                              [
                                    'placeRoom',
                                    'placeBathroom',
                                    'placeCorridor',
                                    'placeDining',
                                    'placeOther',
                                  ]
                                  .map(
                                    (key) => ActionChip(
                                      label: Text(tr(context, key)),
                                      onPressed: () => _place.text =
                                          key == 'placeRoom' && resident != null
                                          ? resident.room
                                          : tr(context, key),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 20,
                              color: _slate,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(context, 'eventTimeLabel'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                  Text(
                                    '${formatDate(_draft.occurredAt)} · ${formatTime(_draft.occurredAt)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: _slate),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: tr(context, 'editEventTime'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _FormLabel(tr(context, 'notesLabel')),
                            ),
                            Text(
                              tr(context, 'optionalLabel'),
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: _slate),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const Key('report-notes'),
                          controller: _notes,
                          minLines: 3,
                          maxLines: 7,
                          decoration: InputDecoration(
                            hintText: tr(context, 'notesHint'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        MediaCapture(onAttached: _attach),
                        if (_savingMedia) const LinearProgressIndicator(),
                        ..._draft.mediaIds.map((id) {
                          final record = repo.mediaById(id);
                          if (record == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: MediaPreview(
                              payload: _mediaPayload(record),
                              onDiscard: () {
                                _draft.mediaIds.remove(id);
                                _changed();
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Text(
                          tr(context, 'reportRoutingHelp'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: _slate, height: 1.5),
                        ),
                        if (_saveFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _InfoBanner(
                              icon: Icons.error_outline,
                              text: tr(context, 'reportNotSaved'),
                              color: _red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ReportResult extends ConsumerWidget {
  final CareEvent event;
  final VoidCallback onDone;
  const _ReportResult({required this.event, required this.onDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(rsaRepositoryProvider);
    final queued = event.syncStatus == SyncStatus.queued;
    final recipients = repo.eligibleRecipients(event);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: queued
                    ? const Color(0xFFFFF4DF)
                    : const Color(0xFFE8F4EF),
                child: Icon(
                  queued ? Icons.cloud_upload_outlined : Icons.check_rounded,
                  size: 38,
                  color: queued ? _amber : _green,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr(context, queued ? 'reportQueued' : 'reportSent'),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                tr(context, queued ? 'reportQueuedHelp' : 'reportSentSubtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: _slate, height: 1.5),
              ),
              const SizedBox(height: 20),
              if (!queued)
                _InfoBanner(
                  icon: event.priority == Priority.low
                      ? Icons.auto_stories_outlined
                      : Icons.notifications_active_outlined,
                  text: event.priority == Priority.low
                      ? tr(context, 'reportLowHelp')
                      : recipients.isEmpty
                      ? tr(context, 'reportNoRecipients')
                      : recipients
                            .map(
                              (s) =>
                                  '${s.name} · ${s.rolesLabelForWard(event.wardId)}',
                            )
                            .join('\n'),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/event/${event.id}'),
                  icon: const Icon(Icons.article_outlined),
                  label: Text(tr(context, 'viewEvent')),
                ),
              ),
              const SizedBox(height: 8),
              if (!queued)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('open-reported-event-chat'),
                    onPressed: () => runAction(context, () async {
                      final conversation = await repo.openEventConversation(
                        event.id,
                      );
                      if (context.mounted) {
                        context.go('/chat/${conversation.id}');
                      }
                    }),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Open chat'),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onDone,
                child: Text(tr(context, 'backToWorkspace')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResidentPicker extends StatefulWidget {
  final List<Resident> residents;
  const _ResidentPicker({required this.residents});
  @override
  State<_ResidentPicker> createState() => _ResidentPickerState();
}

class _ResidentPickerState extends State<_ResidentPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final residents = widget.residents
        .where(
          (r) => '${r.name} ${r.room} ${r.id}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'selectResident'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: tr(context, 'residentSearch'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    ...residents.map(
                      (resident) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 5,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEAF3F5),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: _teal,
                          ),
                        ),
                        title: Text(resident.name),
                        subtitle: Text('${resident.room} · ${resident.id}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, resident.id),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.category_outlined),
                      title: Text(tr(context, 'residentOther')),
                      subtitle: Text(tr(context, 'residentOtherHelp')),
                      onTap: () => Navigator.pop(context, '__other'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});
  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _filter = 'filterWard';
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(rsaRepositoryProvider);
    final notifications = repo.notifications;
    final eventIds = notifications.map((n) => n.eventId).toSet();
    final events =
        repo.events.where((e) {
          if (!eventIds.contains(e.id)) return false;
          return switch (_filter) {
            'filterMyItems' =>
              e.claimedBy == repo.currentUser.id ||
                  notifications.any(
                    (n) =>
                        n.eventId == e.id &&
                        n.recipientIds.contains(repo.currentUser.id),
                  ),
            'filterUnhandled' => e.status == EventStatus.unhandled,
            'filterClosed' => e.status == EventStatus.closed,
            _ => e.status != EventStatus.closed,
          };
        }).toList()..sort((a, b) {
          final priority = b.priority.index.compareTo(a.priority.index);
          return priority != 0
              ? priority
              : b.occurredAt.compareTo(a.occurredAt);
        });
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeading(
          title: tr(context, 'inboxTitle'),
          subtitle: tr(context, 'inboxSubtitle'),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children:
              ['filterMyItems', 'filterWard', 'filterUnhandled', 'filterClosed']
                  .map(
                    (filter) => ChoiceChip(
                      label: Text(tr(context, filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 20),
        if (events.isEmpty)
          EmptyState(
            icon: Icons.inbox_outlined,
            title: tr(context, 'inboxEmpty'),
            message: tr(context, 'inboxEmptyHelp'),
          ),
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OperationalEventCard(event: event, showActions: true),
          ),
        ),
      ],
    );
  }
}

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});
  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  String _query = '';
  EventType? _type;
  Priority? _priority;
  EventStatus? _status;
  String? _resident;
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(rsaRepositoryProvider);
    final events = repo.events.where((event) {
      final resident = repo.residentById(event.residentId ?? '');
      final text =
          '${event.id} ${event.type.label} ${event.notes} ${event.subject} ${event.place} ${resident?.name ?? ''} ${event.residentId ?? ''}'
              .toLowerCase();
      final local = tz.TZDateTime.from(
        event.occurredAt,
        tz.getLocation('Europe/Rome'),
      );
      return text.contains(_query.toLowerCase()) &&
          (_type == null || event.type == _type) &&
          (_priority == null || event.priority == _priority) &&
          (_status == null || event.status == _status) &&
          (_resident == null || event.residentId == _resident) &&
          (_date == null ||
              (local.year == _date!.year &&
                  local.month == _date!.month &&
                  local.day == _date!.day));
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeading(
          title: tr(context, 'diaryTitle'),
          subtitle: tr(context, 'diarySubtitle'),
        ),
        const SizedBox(height: 22),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: tr(context, 'searchDiary'),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 420
                ? constraints.maxWidth
                : 190.0;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<EventType>(
                    key: ValueKey(_type),
                    initialValue: _type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'eventTypeLabel'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr(context, 'allTypes')),
                      ),
                      ...EventType.values.map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(tr(context, _typeKey(e))),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _type = v),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<Priority>(
                    key: ValueKey(_priority),
                    initialValue: _priority,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'priorityLabel'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr(context, 'allPriorities')),
                      ),
                      ...Priority.values.map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(tr(context, _priorityKey(e))),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_resident),
                    initialValue: _resident,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'residentLabel'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr(context, 'allResidents')),
                      ),
                      ...repo.residents.map(
                        (r) =>
                            DropdownMenuItem(value: r.id, child: Text(r.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _resident = v),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<EventStatus>(
                    key: ValueKey(_status),
                    initialValue: _status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'responsibility'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr(context, 'allStatuses')),
                      ),
                      ...EventStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            tr(context, switch (s) {
                              EventStatus.unhandled => 'notTakenCharge',
                              EventStatus.takenCharge => 'takenCharge',
                              EventStatus.closed => 'closedLabel',
                            }),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date ?? repo.now,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (mounted && date != null) setState(() => _date = date);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    _date == null
                        ? tr(context, 'filterDate')
                        : formatDate(_date!),
                  ),
                ),
                if (_date != null ||
                    _type != null ||
                    _priority != null ||
                    _status != null ||
                    _resident != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _date = null;
                      _type = null;
                      _priority = null;
                      _status = null;
                      _resident = null;
                    }),
                    child: Text(tr(context, 'clearFilters')),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          tr(context, 'eventCountLabel', {'count': '${events.length}'}),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: _slate),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          EmptyState(
            icon: Icons.auto_stories_outlined,
            title: tr(context, 'noDiaryEntries'),
            message: tr(context, 'noDiaryEntriesHelp'),
          ),
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OperationalEventCard(event: event),
          ),
        ),
      ],
    );
  }
}

class _OperationalEventCard extends ConsumerWidget {
  final CareEvent event;
  final bool showActions;
  const _OperationalEventCard({required this.event, this.showActions = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(rsaRepositoryProvider);
    final color = _priorityColor(event.priority);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8ED)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/event/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(eventTypeIcon(event.type), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              tr(context, _typeKey(event.type)),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            StatusPill(
                              label: tr(context, _priorityKey(event.priority)),
                              color: color,
                              icon: _priorityIcon(event.priority),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_subject(repo, event)} · ${event.place}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: _slate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: _slate),
                ],
              ),
              if (event.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    event.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${formatDate(event.occurredAt)} · ${formatTime(event.occurredAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _slate),
                  ),
                  Text(
                    tr(context, _statusKey(event)),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: event.status == EventStatus.unhandled
                          ? color
                          : _slate,
                    ),
                  ),
                  if (event.claimedBy != null)
                    Text(
                      repo.staffForDisplay(event.claimedBy!)?.name ??
                          event.claimedBy!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _slate),
                    ),
                ],
              ),
              if (showActions && repo.canClaim(event)) ...[
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    try {
                      await repo.claimEvent(event.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr(context, 'eventClaimed'))),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) showFailure(context, error);
                    }
                  },
                  icon: const Icon(Icons.front_hand_outlined, size: 18),
                  label: Text(tr(context, 'takeCharge')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Own the input for the full dialog lifetime, including its exit transition.
class _EventNoteDialog extends StatefulWidget {
  final bool close;
  const _EventNoteDialog({required this.close});

  @override
  State<_EventNoteDialog> createState() => _EventNoteDialogState();
}

class _EventNoteDialogState extends State<_EventNoteDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(
        () => _error = tr(
          context,
          widget.close ? 'outcomeRequired' : 'correctionRequired',
        ),
      );
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      tr(context, widget.close ? 'closeEventTitle' : 'amendEventTitle'),
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.close) ...[
              Text(
                tr(context, 'reportAmendmentHelp'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: _slate),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              autofocus: true,
              controller: _controller,
              minLines: 3,
              maxLines: 7,
              decoration: InputDecoration(
                labelText: tr(
                  context,
                  widget.close ? 'outcomeLabel' : 'correctionLabel',
                ),
                hintText: tr(
                  context,
                  widget.close ? 'outcomeHint' : 'correctionHint',
                ),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(tr(context, 'cancelLabel')),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(
          tr(context, widget.close ? 'closeEventAction' : 'saveCorrection'),
        ),
      ),
    ],
  );
}

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  Future<void> _edit(
    BuildContext context,
    RsaRepository repo,
    CareEvent event, {
    bool close = false,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EventNoteDialog(close: close),
    );
    if (result == null || !context.mounted) return;
    try {
      if (close) {
        await repo.closeEvent(event.id, result);
      } else {
        await repo.amendEvent(event.id, result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, close ? 'eventClosed' : 'correctionSaved'),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  void _history(BuildContext context, RsaRepository repo, CareEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'versionHistory'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      ...event.versions.reversed.map(
                        (version) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    version.version == 1
                                        ? Icons.description_outlined
                                        : Icons.edit_note_outlined,
                                    size: 20,
                                    color: _teal,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr(context, 'versionLabel', {
                                      'number': '${version.version}',
                                    }),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${repo.staffForDisplay(version.authorId)?.name ?? version.authorId} · ${formatDate(version.createdAt)} · ${formatTime(version.createdAt)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: _slate),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                version.text,
                                style: const TextStyle(height: 1.5),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(rsaRepositoryProvider);
    CareEvent? found;
    try {
      found = repo.eventById(eventId);
    } catch (_) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: tr(context, 'eventMissing'),
        message: tr(context, 'eventMissingHelp'),
      );
    }
    final event = found;
    if (event == null) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: tr(context, 'eventMissing'),
        message: tr(context, 'eventMissingHelp'),
      );
    }
    final notification = repo.notifications
        .where((n) => n.eventId == event.id)
        .firstOrNull;
    final recipients =
        notification?.recipientIds
            .map(repo.staffForDisplay)
            .whereType<StaffMember>()
            .toList() ??
        <StaffMember>[];
    final author = repo.staffForDisplay(event.authorId);
    final claimed = repo.staffForDisplay(event.claimedBy ?? '');
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeading(
          title: tr(context, _typeKey(event.type)),
          subtitle: '${_subject(repo, event)} · ${event.place}',
          action: IconButton(
            onPressed: () => _history(context, repo, event),
            icon: const Icon(Icons.history_rounded),
            tooltip: tr(context, 'versionHistory'),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: tr(context, _priorityKey(event.priority)),
              color: _priorityColor(event.priority),
              icon: _priorityIcon(event.priority),
            ),
            StatusPill(
              label: tr(context, _statusKey(event)),
              color: _slate,
              icon: event.status == EventStatus.closed
                  ? Icons.check_circle_outline
                  : Icons.schedule_outlined,
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(
                label: tr(context, 'eventReference'),
                value: event.id,
              ),
              _DetailLine(
                label: tr(context, 'occurredAt'),
                value:
                    '${formatDate(event.occurredAt)} · ${formatTime(event.occurredAt)}',
              ),
              _DetailLine(
                label: tr(context, 'registeredAt'),
                value:
                    '${formatDate(event.registeredAt)} · ${formatTime(event.registeredAt)}',
              ),
              if (event.synchronizedAt != null &&
                  event.synchronizedAt != event.registeredAt)
                _DetailLine(
                  label: tr(context, 'synchronizedAt'),
                  value:
                      '${formatDate(event.synchronizedAt!)} · ${formatTime(event.synchronizedAt!)}',
                ),
              _DetailLine(
                label: tr(context, 'reportedBy'),
                value: author == null
                    ? event.authorId
                    : '${author.name} · ${author.rolesLabelForWard(event.wardId)}',
              ),
              if (event.notes.isNotEmpty) ...[
                const Divider(height: 26),
                Text(event.notes, style: const TextStyle(height: 1.65)),
              ],
              ...event.mediaIds.map((id) {
                final media = repo.mediaById(id);
                return media == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: MediaPreview(payload: _mediaPayload(media)),
                      );
              }),
              if (event.versions.length > 1) ...[
                const Divider(height: 30),
                Text(
                  tr(context, 'correctionEntry'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...event.versions
                    .skip(1)
                    .map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.text),
                            const SizedBox(height: 4),
                            Text(
                              '${repo.staffForDisplay(v.authorId)?.name ?? v.authorId} · ${formatTime(v.createdAt)}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: _slate),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'responsibility'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                event.status == EventStatus.closed
                    ? tr(context, 'eventClosedBy', {
                        'name':
                            repo.staffForDisplay(event.closedBy ?? '')?.name ??
                            event.closedBy ??
                            '',
                      })
                    : claimed != null
                    ? tr(context, 'eventClaimedBy', {'name': claimed.name})
                    : tr(context, 'readingDoesNotClaim'),
                style: const TextStyle(height: 1.5),
              ),
              if (event.outcome != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    event.outcome!,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              if (repo.canClaim(event)) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await repo.claimEvent(event.id);
                    } catch (error) {
                      if (context.mounted) showFailure(context, error);
                    }
                  },
                  icon: const Icon(Icons.front_hand_outlined),
                  label: Text(tr(context, 'takeCharge')),
                ),
              ],
              if (event.status == EventStatus.takenCharge &&
                  event.claimedBy == repo.currentUser.id) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _edit(context, repo, event, close: true),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr(context, 'closeEvent')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            leading: const Icon(Icons.route_outlined, color: _teal),
            title: Text(tr(context, 'routingTitle')),
            children: [
              if (event.syncStatus == SyncStatus.queued)
                _DetailLine(
                  label: tr(context, 'routingPending'),
                  value: tr(context, 'queuedLabel'),
                )
              else if (event.priority == Priority.low)
                _DetailLine(
                  label: tr(context, 'routingNone'),
                  value: tr(context, 'lowPriorityNote'),
                )
              else ...[
                _DetailLine(
                  label: tr(context, 'routingRecipients'),
                  value: recipients.isEmpty
                      ? tr(context, 'reportNoRecipients')
                      : recipients
                            .map(
                              (r) =>
                                  '${r.name} · ${r.rolesLabelForWard(event.wardId)}',
                            )
                            .join('\n'),
                ),
                if (notification != null) ...[
                  const SizedBox(height: 8),
                  _DetailLine(
                    label: tr(context, 'escalationLabel', {
                      'level': '${notification.escalationLevel}',
                    }),
                    value: formatTime(notification.createdAt),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'linkedRecords'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    key: const Key('open-event-chat'),
                    onPressed: () => runAction(context, () async {
                      final conversation = await repo.openEventConversation(
                        event.id,
                      );
                      if (context.mounted) {
                        context.push('/chat/${conversation.id}');
                      }
                    }),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Open chat'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/diary'),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(tr(context, 'openDiary')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/handover'),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(tr(context, 'openHandover')),
                  ),
                ],
              ),
              if (event.sourceMessageId != null) ...[
                const SizedBox(height: 12),
                _DetailLine(
                  label: tr(context, 'originalMessage'),
                  value:
                      repo.messageById(event.sourceMessageId!)?.text ??
                      event.sourceMessageId!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (repo.can(Capability.report))
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _edit(context, repo, event),
                icon: const Icon(Icons.edit_note_outlined),
                label: Text(tr(context, 'amendEvent')),
              ),
              TextButton.icon(
                onPressed: () => _history(context, repo, event),
                icon: const Icon(Icons.history_rounded),
                label: Text(tr(context, 'versionHistory')),
              ),
            ],
          ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.color = _teal,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color, height: 1.5)),
        ),
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  final String label, value;
  const _DetailLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 420
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _slate),
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(height: 1.5)),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: _slate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(value, style: const TextStyle(height: 1.5)),
                ),
              ],
            ),
    ),
  );
}
