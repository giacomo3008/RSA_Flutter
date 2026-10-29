import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../shared/media_capture.dart';
import '../shared/ui.dart';

/// Document transcription is reviewed separately from medical validation.
class DocumentReviewScreen extends ConsumerStatefulWidget {
  const DocumentReviewScreen({super.key});

  @override
  ConsumerState<DocumentReviewScreen> createState() =>
      _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends ConsumerState<DocumentReviewScreen> {
  String? _selectedId;
  bool _importing = false;

  Future<void> _retainImage(Uint8List bytes, String name) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 20 MB.');
    }
    // Decoding and re-encoding strips EXIF, including location metadata.
    // Bound decoded dimensions without changing the source aspect ratio.
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    Uint8List retained;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        2400 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('This image could not be read.');
      retained = png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
    if (!mounted) return;
    final repository = ref.read(rsaRepositoryProvider);
    final media = await repository.saveMedia(
      bytes: retained,
      mimeType: 'image/png',
      label: name,
    );
    final item = await repository.createDocumentFromMedia(
      media.id,
      title: name,
    );
    if (mounted) setState(() => _selectedId = item.id);
  }

  Future<void> _import(bool camera) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      if (camera) {
        final payload = await captureDocumentPhoto(context);
        if (payload != null && mounted) {
          await _retainImage(payload.bytes, 'Captured document');
        }
      } else {
        final file = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Document images',
              extensions: ['png', 'jpg', 'jpeg', 'webp'],
              mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
              uniformTypeIdentifiers: [
                'public.png',
                'public.jpeg',
                'org.webmproject.webp',
              ],
            ),
          ],
        );
        if (file != null && mounted) {
          await _retainImage(await file.readAsBytes(), file.name);
        }
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(rsaRepositoryProvider);
    if (!repository.can(Capability.care)) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'Document access is restricted',
        message: 'Your account needs clinical access to this ward.',
      );
    }
    final documents = repository.ocrItems;
    final selected =
        documents.where((d) => d.id == _selectedId).firstOrNull ??
        documents.firstOrNull;
    return ListView(
      children: [
        PageHeading(
          title: 'Document review',
          subtitle: 'Check the source. Confirm the transcription.',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _importing ? null : () => _import(true),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Capture document'),
              ),
              FilledButton.icon(
                key: const Key('import-document'),
                onPressed: _importing ? null : () => _import(false),
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: const Text('Upload image'),
              ),
            ],
          ),
        ),
        if (documents.isNotEmpty) ...[
          SectionCard(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final summary = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StatusPill(
                      label: repository.activeWard.name,
                      icon: Icons.apartment_outlined,
                    ),
                    StatusPill(
                      label:
                          '${documents.where((d) => !d.isReviewed).length} awaiting review',
                      color: const Color(0xff946b27),
                    ),
                    StatusPill(
                      label:
                          '${documents.where((d) => d.isReviewed).length} confirmed',
                    ),
                  ],
                );
                final picker = DropdownButtonFormField<String>(
                  key: ValueKey(selected!.id),
                  initialValue: selected.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Document'),
                  items: [
                    for (final document in documents)
                      DropdownMenuItem(
                        value: document.id,
                        child: Text(
                          document.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selectedId = value),
                );
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [summary, const SizedBox(height: 20), picker],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 24),
                    SizedBox(width: 310, child: picker),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _DocumentWorkspace(key: ValueKey(selected!.id), item: selected),
        ] else
          const SectionCard(
            child: EmptyState(
              icon: Icons.document_scanner_outlined,
              title: 'No documents in this ward',
              message:
                  'Capture or upload a document image to begin a transcription review.',
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _DocumentWorkspace extends ConsumerStatefulWidget {
  final OcrItem item;
  const _DocumentWorkspace({super.key, required this.item});
  @override
  ConsumerState<_DocumentWorkspace> createState() => _DocumentWorkspaceState();
}

class _DocumentWorkspaceState extends ConsumerState<_DocumentWorkspace> {
  late final TextEditingController _text;
  bool _checked = false, _saving = false, _correcting = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: widget.item.correctedText ?? widget.item.originalText,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_checked || _saving) return;
    if (_text.text.trim().isEmpty) {
      showFailure(
        context,
        StateError('Enter a transcription before confirming.'),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(rsaRepositoryProvider);
      if (_correcting) {
        await repository.appendOcrCorrection(widget.item.id, _text.text);
      } else {
        await repository.confirmOcr(widget.item.id, _text.text);
      }
      if (mounted) {
        setState(() {
          _correcting = false;
          _checked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reviewed transcription saved.')),
        );
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _source(MediaRecord? media) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(Icons.image_outlined, 'Source document'),
        const SizedBox(height: 18),
        if (media == null)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 330),
            child: const EmptyState(
              icon: Icons.image_not_supported_outlined,
              title: 'Source image unavailable',
              message:
                  'The original image was not included with this record. Check the source before relying on this transcription.',
            ),
          )
        else ...[
          Container(
            height: 440,
            width: double.infinity,
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 5,
              child: Image.memory(
                Uint8List.fromList(media.bytes),
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) => const EmptyState(
                  icon: Icons.broken_image_outlined,
                  title: 'The retained image could not be displayed',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            media.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Retained ${formatDate(media.createdAt)} · ${formatTime(media.createdAt)}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Zoom or pan to check details.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _editor() {
    final item = widget.item;
    final editable = !item.isReviewed || _correcting;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            Icons.fact_check_outlined,
            'Review transcription',
          ),
          const SizedBox(height: 16),
          StatusPill(
            label: item.isReviewed && !_correcting
                ? 'Transcription confirmed'
                : item.hasExtraction
                ? 'Unvalidated extraction'
                : 'Awaiting text extraction',
            color: item.isReviewed && !_correcting
                ? teal
                : const Color(0xff946b27),
          ),
          const SizedBox(height: 18),
          if (item.extractionError != null)
            _Notice(icon: Icons.error_outline, text: item.extractionError!),
          if (!item.hasExtraction && !item.isReviewed) ...[
            const _Notice(
              icon: Icons.edit_note_outlined,
              text:
                  'Automatic text extraction is not available yet. You can enter a manual transcription from the source image and review it below.',
            ),
            const SizedBox(height: 16),
          ],
          if (item.uncertainSegments.isNotEmpty && !item.isReviewed) ...[
            const Text(
              'Check uncertain text',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final segment in item.uncertainSegments)
                  StatusPill(
                    label: segment,
                    icon: Icons.warning_amber_outlined,
                    color: const Color(0xff946b27),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (editable) ...[
            TextField(
              key: const Key('document-transcription'),
              controller: _text,
              minLines: 10,
              maxLines: 18,
              enabled: !_saving,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: _correcting
                    ? 'Corrected transcription'
                    : item.hasExtraction
                    ? 'Reviewed text'
                    : 'Manual transcription',
                hintText: 'Read the source image and enter the document text.',
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const Key('document-review-confirmation'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _checked = value ?? false),
              title: const Text(
                'I have checked this transcription and confirm it is accurate.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const Key('confirm-document-review'),
                  onPressed: _checked && !_saving ? _confirm : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _correcting
                        ? 'Confirm new version'
                        : 'Confirm reviewed text',
                  ),
                ),
                if (_correcting)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _correcting = false;
                            _checked = false;
                            _text.text =
                                item.correctedText ?? item.originalText;
                          }),
                    child: const Text('Cancel correction'),
                  ),
              ],
            ),
          ] else ...[
            SelectableText(
              item.correctedText ?? item.originalText,
              style: const TextStyle(height: 1.7),
            ),
            const SizedBox(height: 18),
            Text(
              'Reviewed by ${ref.read(rsaRepositoryProvider).staffForDisplay(item.reviewedBy!)?.name ?? item.reviewedBy} · ${formatDate(item.reviewedAt!)} · ${formatTime(item.reviewedAt!)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _text.text = item.correctedText ?? item.originalText;
                _checked = false;
                _correcting = true;
              }),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Add correction'),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Confirming a transcription records a text review. It does not provide clinical validation.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _history() {
    final item = widget.item;
    final repository = ref.read(rsaRepositoryProvider);
    return SectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Source and review history',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        leading: const Icon(Icons.history, color: teal),
        children: [
          if (item.hasExtraction)
            _HistoryEntry(
              title: 'Original extraction · unvalidated',
              text: item.originalText,
              subtitle: 'Preserved separately from reviewed text',
            )
          else
            const _HistoryEntry(
              title: 'Source image retained',
              text:
                  'No automatic extraction has been received for this document.',
              subtitle: 'Manual text remains attributable to its reviewer.',
            ),
          if (item.versions.isEmpty && item.isReviewed)
            _HistoryEntry(
              title: 'Reviewed version',
              text: item.correctedText ?? item.originalText,
              subtitle:
                  '${repository.staffForDisplay(item.reviewedBy!)?.name ?? item.reviewedBy} · ${formatTime(item.reviewedAt!)}',
            ),
          for (final version in item.versions)
            _HistoryEntry(
              title: 'Version ${version.version} · reviewed text',
              text: version.text,
              subtitle:
                  '${repository.staffForDisplay(version.authorId)?.name ?? version.authorId} · ${formatDate(version.createdAt)} · ${formatTime(version.createdAt)}',
            ),
          if (item.sourceFingerprint != null)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: SelectableText(
                'Source fingerprint · ${item.sourceFingerprint}',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(rsaRepositoryProvider);
    final sourceId = widget.item.sourceMediaId;
    final media = sourceId == null ? null : repository.mediaById(sourceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 850) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _source(media),
                  const SizedBox(height: 20),
                  _editor(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _source(media)),
                const SizedBox(width: 20),
                Expanded(child: _editor()),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _history(),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionTitle(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: teal),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Notice({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xfffff8ec),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xff946b27), size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.6)),
        ),
      ],
    ),
  );
}

class _HistoryEntry extends StatelessWidget {
  final String title, text, subtitle;
  const _HistoryEntry({
    required this.title,
    required this.text,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: canvas,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 10),
        SelectableText(text, style: const TextStyle(height: 1.6, fontSize: 13)),
      ],
    ),
  );
}
