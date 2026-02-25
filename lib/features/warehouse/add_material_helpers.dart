class AddMaterialHelpers {
  static String formatPrice(double price) {
    // Split the number into integer and decimal parts
    // Use toStringAsFixed(2) to ensure we have exactly 2 decimals
    List<String> parts = price.toStringAsFixed(1).split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];

    final buffer = StringBuffer();

    // Format the integer part with spaces
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(integerPart[i]);
    }

    // Add the decimal part back with a comma (Hungarian style)
    // Only show decimals if they aren't .00 (optional, but cleaner)
    if (decimalPart == "00") {
      return buffer.toString();
    } else {
      return '${buffer.toString()},$decimalPart';
    }
  }
}
