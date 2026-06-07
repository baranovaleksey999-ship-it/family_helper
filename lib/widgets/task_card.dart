import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import 'photo_dialog.dart';

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isParent;
  final String docId;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Function(String) onPhotoUploaded;

  const TaskCard({
    super.key,
    required this.task,
    required this.isParent,
    required this.docId,
    required this.onToggle,
    required this.onDelete,
    required this.onPhotoUploaded,
  });

  Future<void> _uploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final photo =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (photo == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      ),
    );

    try {
      final bytes = await photo.readAsBytes();
      final url = await FirestoreService().uploadPhoto(docId, bytes);

      onPhotoUploaded(url);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Фото отправлено!', style: GoogleFonts.nunito()),
          backgroundColor: const Color(0xFF00CEC9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка: $e', style: GoogleFonts.nunito()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = task['done'] == true;
    final name = task['name'] as String? ?? '';
    final pts = (task['points'] as num?)?.toInt() ?? 0;
    final photos = task['photos'] as List? ?? [];
    final comment = task['comment'] as String? ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: done
            ? Border.all(
                color: const Color(0xFF00CEC9).withOpacity(0.3), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: GestureDetector(
          onTap: isParent ? onToggle : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFF00CEC9).withOpacity(0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: done ? const Color(0xFF00CEC9) : Colors.grey.shade400,
              size: 30,
            ),
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: done ? Colors.grey.shade400 : const Color(0xFF2D3436),
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: done
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : [Colors.amber.shade400, Colors.orange.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('+$pts ⭐',
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            if (comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        comment,
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) =>
                      PhotoDialog(photos: List<String>.from(photos)),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_search_rounded,
                          size: 18, color: Color(0xFF6C5CE7)),
                      const SizedBox(width: 8),
                      Text('Смотреть фото (${photos.length})',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6C5CE7))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: isParent
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Кнопка просмотра фото для родителя (если фото есть)
                  if (photos.isNotEmpty)
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) =>
                            PhotoDialog(photos: List<String>.from(photos)),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.photo_library_rounded,
                            color: Color(0xFF6C5CE7), size: 22),
                      ),
                    ),
                  IconButton(
                    icon: Icon(done ? Icons.undo_rounded : Icons.check_rounded,
                        color: done ? Colors.orange : const Color(0xFF00CEC9)),
                    onPressed: onToggle,
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    onPressed: onDelete,
                    splashRadius: 20,
                  ),
                ],
              )
            : (!done
                ? Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.photo_camera_rounded,
                          color: Colors.white, size: 22),
                      onPressed: () => _uploadPhoto(context),
                      splashRadius: 20,
                    ),
                  )
                : const SizedBox.shrink()),
      ),
    );
  }
}
