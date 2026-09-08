import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../haptics/haptic_service.dart';
import '../theme/app_theme.dart';
import 'pack_models.dart';
import 'pack_providers.dart';

Future<StickerPack?> showCreatePackSheet(
  BuildContext context, {
  StickerPack? existing,
}) {
  return showModalBottomSheet<StickerPack>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _PackFormSheet(existing: existing),
      );
    },
  );
}

class _PackFormSheet extends ConsumerStatefulWidget {
  const _PackFormSheet({this.existing});

  final StickerPack? existing;

  @override
  ConsumerState<_PackFormSheet> createState() => _PackFormSheetState();
}

class _PackFormSheetState extends ConsumerState<_PackFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _author;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _author = TextEditingController(text: widget.existing?.author ?? 'Me');
  }

  @override
  void dispose() {
    _name.dispose();
    _author.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final controller = ref.read(packsProvider.notifier);
      final pack = widget.existing == null
          ? await controller.createPack(name: _name.text, author: _author.text)
          : await controller.renamePack(
              packId: widget.existing!.id,
              name: _name.text,
              author: _author.text,
            );
      if (!mounted) return;
      hapticService.success();
      Navigator.pop(context, pack);
    } catch (error) {
      if (!mounted) return;
      hapticService.error();
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'New pack' : 'Edit pack',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'WhatsApp needs a pack name, an author, and a 96×96 tray icon. We’ll make the tray icon for you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: WhatsAppPackRules.maxNameLength,
            decoration: const InputDecoration(
              labelText: 'Pack name',
              hintText: 'Monday moods',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _author,
            textCapitalization: TextCapitalization.words,
            maxLength: WhatsAppPackRules.maxAuthorLength,
            decoration: const InputDecoration(
              labelText: 'Author',
              hintText: 'Your name',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () {
                      hapticService.buttonTap();
                      _submit();
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Text(widget.existing == null ? 'Create pack' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
