import 'dart:ui';

/// Fixed institutional data and visual constants for Ingenieria Galia, c.a.
class CompanyConstants {
  const CompanyConstants._();

  static const String companyName = 'Ingenieria Galia, c.a.';
  static const String companyRif = 'RIF. J-31013263-1';
  static const String phonesLabel = 'Teléfonos:';
  static const String phonePrimary = '625-63-82';
  static const String phoneSecondary = '04142-30-07-07';
  static const String companyAddress =
      'Canonigos a Esperanza Edificio Los Canonigos, Piso5 , N ro.51- Altagracia, Caracas';
  static const String taxNote = 'No incluye el impuesto de ley';
  static const String leftSignatureLabel = 'Firma (s) Autorizada (s)';
  static const String rightSignatureLabel = 'De Ud.(s) Atte. Ss. Ss. y Amigo (s)';

  static const String defaultPaymentTerms = '70% al aprobar\n30% al finalizar';
  static const String defaultExecutionTime = '5 dias habiles';

  static const String defaultLogoAsset = 'assets/images/logo_ig.png';

  /// Exact navy/royal blue measured from the reference header separator (#2E3092).
  static const Color headerBlueColor = Color(0xFF2E3092);
  static const Color inkBlack = Color(0xFF1A1A1A);

  /// US Letter page dimensions in PDF points (8.5 x 11 inches).
  static const double pageWidth = 612.0;
  static const double pageHeight = 792.0;
}
