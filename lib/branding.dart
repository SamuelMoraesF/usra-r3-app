/// Identidade textual exibida pelo aplicativo.
///
/// Identificadores técnicos (package name, application ID e nome do banco)
/// permanecem definidos nas configurações nativas e não devem ser alterados
/// para acompanhar mudanças de marca.
abstract final class AppBranding {
  static const name = 'USRA R3';
  static const description = 'Rede de Radiocomunicação Resiliente (R3).';
  static const publisher = 'USRA (União Santamariense de Radioamadores)';
  static const website = 'https://py3ur.blogspot.com/';
  static const aboutSummary = '$name — logbook offline da $description';
  static const csvSubject = '$name logbook';
  static const markAsset = 'assets/branding/usra_r3_mark.png';
}
