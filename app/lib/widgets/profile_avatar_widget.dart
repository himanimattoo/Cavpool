import 'package:flutter/material.dart';

class ProfileAvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final double radius;
  final IconData fallbackIcon;
  final String? fallbackText;
  
  const ProfileAvatarWidget({
    super.key,
    this.photoUrl,
    this.radius = 30,
    this.fallbackIcon = Icons.person,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
        ),
      );
    }
    
    return _buildFallback();
  }
  
  Widget _buildFallback() {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Text(
        fallbackText!.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      );
    }
    
    return Icon(
      fallbackIcon,
      size: radius * 0.8,
      color: Colors.grey[600],
    );
  }
}