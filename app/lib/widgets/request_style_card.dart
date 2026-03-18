import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'distance_chip.dart';

class RequestStyleCard extends StatelessWidget {
  const RequestStyleCard({
    super.key,
    required this.startAddress,
    required this.endAddress,
    required this.statusLabel,
    required this.statusColor,
    required this.dateText,          // e.g., "31/10 at 1:43 PM"
    this.rightMoneyText,             // e.g., "Max $20" OR "\$20"
    this.trailingMetaText,           // e.g., "per seat"
    this.distanceInMeters,           // Distance in meters, will be formatted
    this.onLeftPressed,
    this.onRightPressed,
    this.leftLabel = 'View Details',
    this.rightLabel = 'Cancel',
    this.rightButtonColor = Colors.red,
    this.showButtons = true,
  });

  final String startAddress;
  final String endAddress;
  final String statusLabel;
  final Color statusColor;
  final String dateText;
  final String? rightMoneyText;
  final String? trailingMetaText;
  final double? distanceInMeters;

  final VoidCallback? onLeftPressed;
  final VoidCallback? onRightPressed;
  final String leftLabel;
  final String rightLabel;
  final Color rightButtonColor;
  final bool showButtons;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.my_location, color: Color(0xFFE57200), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          startAddress,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          endAddress,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(dateText, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
              if (distanceInMeters != null && distanceInMeters! > 0) ...[
                const SizedBox(width: 12),
                DistanceText(
                  distanceInMeters: distanceInMeters!,
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ],
              if (rightMoneyText != null) ...[
                const SizedBox(width: 16),
                Text(
                  '\$${rightMoneyText!}'
                  '${trailingMetaText != null ? ' ${trailingMetaText!}' : ''}',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          if (showButtons) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onLeftPressed,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE57200)),
                      foregroundColor: const Color(0xFFE57200),
                    ),
                    child: Text(leftLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRightPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: rightButtonColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(rightLabel),
                  ),
                ),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}
