import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;
  final bool isParent;
  final int points;
  final VoidCallback onBuy;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  const RewardCard({
    super.key,
    required this.reward,
    required this.isParent,
    required this.points,
    required this.onBuy,
    required this.onReset,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bought = reward['bought'] == true;
    final name = reward['name'] as String? ?? '';
    final cost = (reward['cost'] as num?)?.toInt() ?? 0;
    final canBuy = !isParent && !bought && points >= cost;

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
              offset: const Offset(0, 4)),
        ],
        border: bought
            ? Border.all(
                color: const Color(0xFF6C5CE7).withOpacity(0.3), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: bought
                ? const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)])
                : LinearGradient(
                    colors: [Colors.grey.shade400, Colors.grey.shade500]),
            shape: BoxShape.circle,
            boxShadow: bought
                ? [
                    BoxShadow(
                        color: const Color(0xFF6C5CE7).withOpacity(0.4),
                        blurRadius: 10)
                  ]
                : null,
          ),
          child: Icon(
            bought ? Icons.check_rounded : Icons.card_giftcard_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: bought ? Colors.grey.shade400 : const Color(0xFF2D3436),
            decoration: bought ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(children: [
          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
          const SizedBox(width: 4),
          Text('$cost баллов',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: Colors.grey.shade600)),
        ]),
        trailing: isParent
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                if (bought)
                  IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Color(0xFF6C5CE7)),
                      onPressed: onReset,
                      splashRadius: 20),
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    onPressed: onDelete,
                    splashRadius: 20),
              ])
            : !bought
                ? Container(
                    decoration: BoxDecoration(
                      gradient: canBuy
                          ? const LinearGradient(
                              colors: [Color(0xFF00CEC9), Color(0xFF81ECEC)])
                          : LinearGradient(colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade500
                            ]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: canBuy
                          ? [
                              BoxShadow(
                                  color:
                                      const Color(0xFF00CEC9).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: canBuy ? onBuy : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      child: Text('Купить',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  )
                : null,
      ),
    );
  }
}
