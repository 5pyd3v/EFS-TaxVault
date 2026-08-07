/// Centralized route paths so screens never hard-code path strings inline.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/auth/sign-in';
  static const signUp = '/auth/sign-up';
  static const onboarding = '/auth/onboarding';

  static const home = '/home';
  static const vault = '/vault';
  static const scan = '/scan';
  static const scanReview = '/scan/review';
  static const processingPattern = '/scan/processing/:documentId';
  static const invoiceReviewPattern = '/invoices/:invoiceId/review';
  static const reports = '/reports';
  static const profile = '/profile';

  static String processing(String documentId) => '/scan/processing/$documentId';
  static String invoiceReview(String invoiceId) => '/invoices/$invoiceId/review';
}
