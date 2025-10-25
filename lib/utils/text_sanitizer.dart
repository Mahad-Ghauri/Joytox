// ignore_for_file: unused_element

/// Utility class for sanitizing text to prevent UTF-16 encoding errors
class TextSanitizer {
  /// Sanitizes text to ensure it's valid UTF-16 and safe for Flutter text rendering
  static String sanitizeText(String? text) {
    if (text == null || text.isEmpty) {
      return "";
    }

    try {
      // Only remove truly problematic characters, preserve normal text
      String sanitized = text
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
              '') // Remove control characters
          .replaceAll(RegExp(r'[\uFFFE\uFFFF]'),
              '') // Remove BOM and invalid characters
          .trim();

      // Only return fallback if text is completely empty
      if (sanitized.isEmpty) {
        return "";
      }

      return sanitized;
    } catch (e) {
      print('TextSanitizer: Error sanitizing text: $e');
      return text; // Return original text if sanitization fails
    }
  }

  /// Sanitizes text specifically for display names
  static String sanitizeDisplayName(String? name) {
    if (name == null || name.isEmpty) {
      return "Loading...";
    }

    final sanitized = sanitizeText(name);

    // Only return "Loading..." if the text is completely empty after sanitization
    if (sanitized.isEmpty) {
      return "Loading...";
    }

    // Limit length to prevent UI issues
    if (sanitized.length > 50) {
      return sanitized.substring(0, 47) + "...";
    }

    return sanitized;
  }

  /// Sanitizes text for post descriptions
  static String sanitizePostText(String? text) {
    if (text == null || text.isEmpty) {
      return "";
    }

    final sanitized = sanitizeText(text);

    // Limit length for post descriptions
    if (sanitized.length > 500) {
      return sanitized.substring(0, 497) + "...";
    }

    return sanitized;
  }

  /// Checks if a string contains valid UTF-16 characters
  static bool isValidUtf16(String text) {
    try {
      // Try to create a TextSpan with the text to test if it's valid
      final codeUnits = text.codeUnits;
      for (int i = 0; i < codeUnits.length; i++) {
        int codeUnit = codeUnits[i];

        // Check for invalid UTF-16 sequences
        if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
          // High surrogate - check if next character is low surrogate
          if (i + 1 >= codeUnits.length) return false;
          int nextCodeUnit = codeUnits[i + 1];
          if (nextCodeUnit < 0xDC00 || nextCodeUnit > 0xDFFF) return false;
          i++; // Skip the low surrogate
        } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
          // Low surrogate without high surrogate
          return false;
        } else if (codeUnit == 0xFFFE || codeUnit == 0xFFFF) {
          // Invalid characters
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
