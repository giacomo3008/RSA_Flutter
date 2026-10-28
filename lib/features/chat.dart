import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/media.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/repository.dart';
import '../shared/media_capture.dart';
import '../shared/ui.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  const ChatScreen({super.key, this.conversationId});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _search = TextEditingController();
  bool _startingConversation = false;

  Future<void> _newConversation(RsaRepository repository) async {
    final personId = await showDialog<String>(
      context: context,
      builder: (_) => _NewConversationDialog(
        contacts: repository.conversationContacts,
        wardId: repository.activeWard.id,
      ),
    );
    if (personId == null || !mounted) return;
    setState(() => _startingConversation = true);
    await runAction(context, () async {
      final conversation = await repository.startDirectConversation(personId);
      if (mounted) context.go('/chat/${conversation.id}');
    });
    if (mounted) setState(() => _startingConversation = false);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(rsaRepositoryProvider);
    if (!repo.can(Capability.chat)) {
      return EmptyState(
        icon: Icons.lock_outline,
        title: tr(context, 'conversationUnavailable'),
        message: tr(context, 'conversationDenied'),
      );
    }
    final conversations = repo.conversations;
    final query = _search.text.trim().toLowerCase();
    final filtered = conversations
        .where(
          (conversation) =>
              query.isEmpty ||
              repo
                  .conversationTitle(conversation)
                  .toLowerCase()
                  .contains(query) ||
              repo
                  .messagesFor(conversation.id)
                  .any((m) => m.text.toLowerCase().contains(query)),
        )
        .toList();
    final selected = conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 780;
        final active =
            selected ?? (expanded ? conversations.firstOrNull : null);
        if (widget.conversationId != null && selected == null) {
          return EmptyState(
            icon: Icons.lock_outline,
            title: tr(context, 'conversationUnavailable'),
            message: tr(context, 'conversationDenied'),
          );
        }
        final conversationList = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Conversations',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton.filled(
                        key: const Key('new-conversation'),
                        tooltip: 'New conversation',
                        onPressed: _startingConversation
                            ? null
                            : () => _newConversation(repo),
                        icon: _startingConversation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(context, 'chatSubtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr(context, 'searchConversations'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: tr(context, 'noConversations'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final conversation = filtered[i];
                        final messages = repo.messagesFor(conversation.id);
                        final last = messages.lastOrNull;
                        final unread = repo.unreadCount(conversation.id);
                        final assistant =
                            conversation.kind == ConversationKind.assistant;
                        return Material(
                          color: active?.id == conversation.id
                              ? const Color(0xffe5f0ec)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: assistant
                                  ? const Color(0xffdcece6)
                                  : const Color(0xffeef1f4),
                              foregroundColor: const Color(0xff276e61),
                              child: Icon(switch (conversation.kind) {
                                ConversationKind.assistant =>
                                  Icons.auto_awesome_outlined,
                                ConversationKind.ward => Icons.groups_outlined,
                                ConversationKind.direct => Icons.person_outline,
                                ConversationKind.event =>
                                  Icons.assignment_outlined,
                              }),
                            ),
                            title: Text(
                              repo.conversationTitle(conversation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: active?.id == conversation.id
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                last?.text.isNotEmpty == true
                                    ? last!.text
                                    : last?.mediaId != null
                                    ? tr(context, 'attachmentMessage')
                                    : tr(
                                        context,
                                        assistant
                                            ? 'assistantIntroShort'
                                            : 'noMessagesYet',
                                      ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (last != null)
                                  Text(
                                    formatTime(last.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                if (unread > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Badge(label: Text('$unread')),
                                  ),
                              ],
                            ),
                            onTap: () => context.go('/chat/${conversation.id}'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
        if (!expanded) {
          return active == null
              ? conversationList
              : _ConversationThread(
                  key: ValueKey('${repo.currentUser.id}-${active.id}'),
                  conversation: active,
                  compact: true,
                );
        }
        return Row(
          children: [
            SizedBox(width: 322, child: conversationList),
            const VerticalDivider(width: 1),
            Expanded(
              child: active == null
                  ? EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: tr(context, 'chooseConversation'),
                    )
                  : _ConversationThread(
                      key: ValueKey('${repo.currentUser.id}-${active.id}'),
                      conversation: active,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NewConversationDialog extends StatefulWidget {
  final List<StaffMember> contacts;
  final String wardId;
  const _NewConversationDialog({required this.contacts, required this.wardId});

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _roles(StaffMember person) => person.rolesLabelForWard(widget.wardId);

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final contacts = widget.contacts
        .where(
          (person) =>
              query.isEmpty ||
              person.name.toLowerCase().contains(query) ||
              _roles(person).toLowerCase().contains(query),
        )
        .toList();
    return AlertDialog(
      title: const Text('New conversation'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a colleague in your current ward.'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('conversation-contact-search'),
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or role',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: contacts.isEmpty
                  ? const Center(child: Text('No matching colleagues.'))
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final person = contacts[index];
                        return ListTile(
                          leading: Avatar(person.initials),
                          title: Text(person.name),
                          subtitle: Text(_roles(person)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, person.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'cancel')),
        ),
      ],
    );
  }
}

class _ConversationThread extends ConsumerStatefulWidget {
  final Conversation conversation;
  final bool compact;
  const _ConversationThread({
    super.key,
    required this.conversation,
    this.compact = false,
  });
  @override
  ConsumerState<_ConversationThread> createState() =>
      _ConversationThreadState();
}

class _ConversationThreadState extends ConsumerState<_ConversationThread> {
  final TextEditingController _composer = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Message? _reply;
  MediaPayload? _attachment;
  String? _storedMediaId;
  bool _sending = false, _searching = false;
  int _messageCount = 0;
  Timer? _draftDebounce;
  late final RsaRepository _repository;
  late final String _ownerId;

  bool get _samePersona => _repository.currentUser.id == _ownerId;

  bool get _assistant => widget.conversation.kind == ConversationKind.assistant;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(rsaRepositoryProvider);
    _ownerId = _repository.currentUser.id;
    final draft = _repository.chatDraftFor(widget.conversation.id);
    if (draft != null) {
      _composer.text = draft['text'] as String? ?? '';
      _storedMediaId = draft['mediaId'] as String?;
      final media = _storedMediaId == null
          ? null
          : _repository.mediaById(_storedMediaId!);
      if (media != null) _attachment = _payloadFromRecord(media);
      final replyTo = draft['replyTo'] as String?;
      _reply = replyTo == null ? null : _repository.messageById(replyTo);
    }
    _composer.addListener(_queueDraftSave);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final repo = ref.read(rsaRepositoryProvider);
      try {
        await repo.markConversationRead(widget.conversation.id);
      } catch (error) {
        if (mounted) showFailure(context, error);
      }
    });
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    if (!_sending && _samePersona) {
      unawaited(
        _repository
            .saveChatDraft(
              widget.conversation.id,
              _composer.text,
              mediaId: _storedMediaId,
              replyTo: _reply?.id,
            )
            .catchError((_) {}),
      );
    }
    _composer.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  MediaPayload _payloadFromRecord(MediaRecord media) => MediaPayload(
    kind: media.mimeType.startsWith('image/') ? 'photo' : 'audio',
    bytes: Uint8List.fromList(media.bytes),
    mimeType: media.mimeType,
    name: media.label,
    synthetic: media.synthetic,
    durationMs: media.durationMs,
    transcript: media.transcript,
  );

  void _queueDraftSave() {
    _draftDebounce?.cancel();
    if (_sending || !_samePersona) return;
    _draftDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!_samePersona) return;
      try {
        await _repository.saveChatDraft(
          widget.conversation.id,
          _composer.text,
          mediaId: _storedMediaId,
          replyTo: _reply?.id,
        );
      } catch (error) {
        if (mounted) showFailure(context, error);
      }
    });
  }

  Future<void> _attachPayload(MediaPayload payload) async {
    setState(() {
      _attachment = payload;
      _storedMediaId = null;
      _sending = true;
    });
    try {
      final id = await _saveAttachment(_repository);
      if (!mounted || !_samePersona) return;
      await _repository.saveChatDraft(
        widget.conversation.id,
        _composer.text,
        mediaId: id,
        replyTo: _reply?.id,
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (_composer.text.isNotEmpty || _attachment != null) _queueDraftSave();
      }
    }
  }

  Future<String?> _saveAttachment(RsaRepository repo) async {
    if (_storedMediaId != null) return _storedMediaId;
    final payload = _attachment;
    if (payload == null) return null;
    final saved = await repo.saveMedia(
      bytes: payload.bytes,
      mimeType: payload.mimeType,
      label: payload.name,
      synthetic: payload.synthetic,
      durationMs: payload.durationMs,
      transcript: payload.transcript,
    );
    _storedMediaId = saved.id;
    return saved.id;
  }

  Future<void> _send([String? suggestion]) async {
    if (_sending) return;
    _draftDebounce?.cancel();
    final text = (suggestion ?? _composer.text).trim();
    if (text.isEmpty && _attachment == null) return;
    setState(() => _sending = true);
    final repo = ref.read(rsaRepositoryProvider);
    try {
      final mediaId = await _saveAttachment(repo);
      if (!mounted || !_samePersona) return;
      await repo.sendMessage(
        widget.conversation.id,
        text,
        replyTo: _reply?.id,
        mediaId: mediaId,
      );
      if (!mounted) return;
      setState(() {
        _composer.clear();
        _reply = null;
        _attachment = null;
        _storedMediaId = null;
      });
      _scrollToEnd();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (_composer.text.isNotEmpty || _attachment != null) _queueDraftSave();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _createEvent(Message message) {
    final repo = ref.read(rsaRepositoryProvider);
    context.push(
      '/report',
      extra: EventDraft(
        idempotencyKey: 'message-${message.id}',
        occurredAt: repo.now,
        notes: message.text,
        sourceMessageId: message.id,
        mediaIds: [if (message.mediaId != null) message.mediaId!],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(rsaRepositoryProvider);
    final allMessages = repo.messagesFor(widget.conversation.id);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (allMessages.length != _messageCount) {
      _messageCount = allMessages.length;
      _scrollToEnd();
    }
    final query = _search.text.trim().toLowerCase();
    final messages = allMessages
        .where((m) => query.isEmpty || m.text.toLowerCase().contains(query))
        .toList();
    final event = widget.conversation.eventId == null
        ? null
        : repo.eventById(widget.conversation.eventId!);
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (widget.compact)
                IconButton(
                  onPressed: () => context.go('/chat'),
                  tooltip: tr(context, 'backToConversations'),
                  icon: const Icon(Icons.arrow_back),
                ),
              CircleAvatar(
                backgroundColor: const Color(0xffe5f0ec),
                child: Icon(
                  _assistant
                      ? Icons.auto_awesome_outlined
                      : Icons.chat_bubble_outline,
                  color: const Color(0xff276e61),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.conversationTitle(widget.conversation),
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      tr(
                        context,
                        _assistant
                            ? 'privateAssistant'
                            : widget.conversation.kind ==
                                  ConversationKind.direct
                            ? 'directConversation'
                            : 'wardConversation',
                      ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _searching = !_searching),
                tooltip: tr(context, 'searchHistory'),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: tr(context, 'searchHistory'),
                suffixIcon: IconButton(
                  onPressed: () {
                    _search.clear();
                    setState(() {});
                  },
                  tooltip: tr(context, 'clearSearch'),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
        if (event != null && !keyboardOpen)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffe0e6e3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(label: event.priority.label),
                    Text(
                      event.type.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(formatTime(event.occurredAt)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.claimedBy == null
                      ? tr(context, 'notTakenCharge')
                      : '${event.status.label} · ${repo.staffForDisplay(event.claimedBy!)?.name ?? event.claimedBy}',
                ),
                TextButton(
                  onPressed: () => context.push('/event/${event.id}'),
                  child: Text(tr(context, 'viewLinkedEvent')),
                ),
              ],
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? _assistant
                    ? _AssistantWelcome(onSuggestion: _send)
                    : EmptyState(
                        icon: Icons.forum_outlined,
                        title: tr(
                          context,
                          query.isEmpty
                              ? 'startConversation'
                              : 'noMessagesFound',
                        ),
                        message: tr(
                          context,
                          query.isEmpty ? 'conversationIntro' : 'changeSearch',
                        ),
                      )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final author = repo.staffForDisplay(message.authorId);
                    final mine = message.authorId == repo.currentUser.id;
                    final replied = message.replyTo == null
                        ? null
                        : allMessages
                              .where((m) => m.id == message.replyTo)
                              .firstOrNull;
                    final media = message.mediaId == null
                        ? null
                        : repo.mediaById(message.mediaId!);
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                          decoration: BoxDecoration(
                            color: message.ai
                                ? const Color(0xffe9f3ee)
                                : mine
                                ? const Color(0xffdeebe6)
                                : Colors.white,
                            border: Border.all(color: const Color(0xffe0e7e3)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    message.ai
                                        ? tr(context, 'rsaAssistant')
                                        : author?.name ??
                                              (message.authorId == 'system'
                                                  ? tr(context, 'systemMessage')
                                                  : message.authorId),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (message.ai)
                                    StatusPill(label: tr(context, 'aiLabel')),
                                  if (!message.ai && author != null)
                                    Text(
                                      author.rolesLabelForWard(
                                        widget.conversation.wardId,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                ],
                              ),
                              if (replied != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .6),
                                    border: const Border(
                                      left: BorderSide(
                                        color: Color(0xff2f7d6d),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    replied.text.isEmpty
                                        ? tr(context, 'attachmentMessage')
                                        : replied.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              if (message.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SelectableText(message.text),
                                ),
                              if (media != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: MediaPreview(
                                    payload: MediaPayload(
                                      kind: media.mimeType.startsWith('image/')
                                          ? 'photo'
                                          : 'audio',
                                      bytes: Uint8List.fromList(media.bytes),
                                      mimeType: media.mimeType,
                                      name: media.label,
                                      synthetic: media.synthetic,
                                      durationMs: media.durationMs,
                                      transcript: media.transcript,
                                    ),
                                  ),
                                ),
                              if (message.sourceEventIds.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  tr(context, 'sourcesLabel'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: message.sourceEventIds.map((id) {
                                    final source = repo.eventById(id);
                                    if (source == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return ActionChip(
                                      avatar: const Icon(Icons.link, size: 16),
                                      label: Text(
                                        '${source.type.label} · ${formatTime(source.occurredAt)}',
                                      ),
                                      onPressed: () =>
                                          context.push('/event/$id'),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    formatTime(message.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                  if (mine)
                                    Text(
                                      message.delivery,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  if (!_assistant)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setState(() => _reply = message);
                                        _queueDraftSave();
                                      },
                                      tooltip: tr(context, 'replyMessage'),
                                      icon: const Icon(Icons.reply, size: 18),
                                    ),
                                  if (!message.ai &&
                                      message.authorId != 'system' &&
                                      repo.currentUser.can(Capability.report))
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _createEvent(message),
                                      tooltip: tr(
                                        context,
                                        'createEventFromMessage',
                                      ),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_assistant && messages.isNotEmpty && !keyboardOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    label: Text(tr(context, 'suggestUnresolved')),
                    onPressed: _sending
                        ? null
                        : () => _send(tr(context, 'suggestUnresolved')),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: Text(tr(context, 'suggestSummary')),
                    onPressed: _sending
                        ? null
                        : () => _send(tr(context, 'suggestSummary')),
                  ),
                ],
              ),
            ),
          ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xffe2e8e5))),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_reply != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tr(context, 'replyingTo')} ${_reply!.text}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => _reply = null);
                        _queueDraftSave();
                      },
                      tooltip: tr(context, 'cancelReply'),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              if (_attachment != null && !keyboardOpen)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: SingleChildScrollView(
                    child: MediaPreview(
                      payload: _attachment!,
                      onDiscard: _sending
                          ? null
                          : () {
                              setState(() {
                                _attachment = null;
                                _storedMediaId = null;
                              });
                              _queueDraftSave();
                            },
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: tr(
                          context,
                          _assistant ? 'askAssistantHint' : 'messageTeamHint',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
                    tooltip: tr(context, 'sendMessage'),
                    icon: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_sending && !keyboardOpen)
                MediaCapture(onAttached: _attachPayload),
              if (_assistant && !keyboardOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tr(context, 'assistantBoundary'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantWelcome extends StatelessWidget {
  final ValueChanged<String> onSuggestion;
  const _AssistantWelcome({required this.onSuggestion});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0xffdfede6),
          child: Icon(
            Icons.auto_awesome_outlined,
            size: 30,
            color: Color(0xff276e61),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          tr(context, 'assistantWelcome'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(tr(context, 'assistantWelcomeBody')),
        const SizedBox(height: 24),
        for (final key in [
          'suggestSummary',
          'suggestUnresolved',
          'suggestDraft',
          'suggestResident',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () => onSuggestion(tr(context, key)),
              icon: const Icon(Icons.arrow_outward, size: 18),
              label: Text(tr(context, key)),
            ),
          ),
      ],
    ),
  );
}
