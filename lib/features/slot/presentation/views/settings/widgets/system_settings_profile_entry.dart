import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SystemSettingsProfileEntry extends StatelessWidget {
  const SystemSettingsProfileEntry({
    super.key,
    required this.textColor,
    required this.avatarAssetPath,
    required this.onTap,
  });

  final Color textColor;
  final String avatarAssetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'My Profile',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.36),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: textColor.withValues(alpha: 0.16),
                    width: 2,
                  ),
                ),
                child: Image.asset(avatarAssetPath, fit: BoxFit.contain),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY PROFILE',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AVATAR AND ACCOUNT SECURITY',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: textColor.withValues(alpha: 0.70),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
