import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatWidget extends StatefulWidget {
  final String familyCode;
  final String senderName;

  const ChatWidget(
      {super.key, required this.familyCode, required this.senderName});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  void _sendMessage() async {
    if (_msgCtrl.text.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.familyCode)
        .collection('messages')
        .add({
      'text': _msgCtrl.text,
      'sender': widget.senderName,
      'time': FieldValue.serverTimestamp(),
    });
    _msgCtrl.clear();
    _scrollCtrl.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.familyCode)
              .collection('messages')
              .orderBy('time', descending: true)
              .snapshots(),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final messages = snapshot.data!.docs;
            return ListView.builder(
              reverse: true,
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final msg = messages[i].data() as Map<String, dynamic>;
                final isMe = msg['sender'] == widget.senderName;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF6C5CE7) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isMe
                            ? const Radius.circular(20)
                            : const Radius.circular(4),
                        bottomRight: isMe
                            ? const Radius.circular(4)
                            : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5)
                      ],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(msg['sender'] ?? '',
                                style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6C5CE7))),
                          Text(msg['text'] ?? '',
                              style: GoogleFonts.nunito(
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF2D3436))),
                        ]),
                  ),
                );
              },
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ]),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _msgCtrl,
                  decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: GoogleFonts.nunito(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20)))),
          const SizedBox(width: 8),
          GestureDetector(
              onTap: _sendMessage,
              child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                      color: Color(0xFF6C5CE7), shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22))),
        ]),
      ),
    ]);
  }
}
