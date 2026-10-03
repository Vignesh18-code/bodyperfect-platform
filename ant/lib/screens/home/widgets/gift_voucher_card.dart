import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class GiftVoucherCard extends StatefulWidget {
  final Future<void> Function() onCollect;
  const GiftVoucherCard({super.key, required this.onCollect});

  @override
  State<GiftVoucherCard> createState() => _GiftVoucherCardState();
}

class _GiftVoucherCardState extends State<GiftVoucherCard> {
  static const _image = 'assets/images/1000 Voucher.jpg';
  static const _gold = Color(0xFF936C22);
  static const _imageRatio = 1796 / 896;
  bool _opening = false;

  Future<void> _collect() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onCollect();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open booking. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _viewVoucher() {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.navy.withValues(alpha: .75),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your gift voucher',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close voucher',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.asset(
                    _image,
                    fit: BoxFit.contain,
                    semanticLabel:
                        'AED 1,000 BodyPerfect gift voucher. Terms and conditions apply.',
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Pinch to zoom · Terms and conditions apply',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontFamily: AppTypography.family,
      color: AppColors.navy,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFCF4), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEDE1C3)),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: .06),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6EDD6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: _gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A GIFT FOR YOU',
                      style: textStyle.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: _gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'AED 1,000 gift voucher',
                style: textStyle.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Book a visit to enquire about collecting your gift.',
                style: textStyle.copyWith(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: const Color(0xFFF7EDD2),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _viewVoucher,
                  child: AspectRatio(
                    aspectRatio: _imageRatio,
                    child: Image.asset(
                      _image,
                      cacheWidth: 1000,
                      fit: BoxFit.contain,
                      semanticLabel: 'View AED 1,000 gift voucher',
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          color: _gold,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the voucher to enlarge',
                style: textStyle.copyWith(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _opening ? null : _collect,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: textStyle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_opening)
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.card_giftcard_rounded, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _opening ? 'Opening booking…' : 'Collect your gift',
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (!_opening)
                        const Icon(Icons.arrow_forward_rounded, size: 17),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Center(
                child: Text(
                  'Voucher terms and conditions apply.',
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    fontSize: 10,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
