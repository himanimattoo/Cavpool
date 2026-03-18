import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VerificationCodeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyStateMessage;
  final String? code;
  final DateTime? expiresAt;
  final bool isLoading;
  final VoidCallback? onCopy;
  final VoidCallback? onRefresh;
  final Widget? actionButton;
  final Color accentColor;

  const VerificationCodeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyStateMessage,
    this.code,
    this.expiresAt,
    this.isLoading = false,
    this.onCopy,
    this.onRefresh,
    this.actionButton,
    this.accentColor = const Color(0xFF1A73E8),
  });

  bool get _hasCode => code != null && code!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.sync),
                  tooltip: 'Reload code (new codes only generated after expiration)',
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!_hasCode)
            _buildEmptyState()
          else
            _buildCodeDisplay(context),
          if (actionButton != null) ...[
            const SizedBox(height: 12),
            actionButton!,
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_clock,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              emptyStateMessage,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                _formatCode(),
                style: GoogleFonts.robotoMono(
                  fontSize: 36,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (onCopy != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Code'),
                ),
              ),
            if (onCopy != null && onRefresh != null)
              const SizedBox(width: 8),
            if (onRefresh != null)
              Expanded(
                child: TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Reload'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _formatCode() {
    if (code == null) return '----';
    if (code!.length == 4) {
      return code!
          .split('')
          .map((digit) => digit.trim())
          .join(' ');
    }
    return code!;
  }

}
