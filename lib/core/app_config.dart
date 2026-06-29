class AppConfig {
  /// The production HTTPS domain used for App Links / Universal Links.
  /// When scanned externally, this URL will open the app directly.
  static const String deepLinkDomain = 'https://university-connect-52779.web.app';
  
  /// Custom URI scheme fallback for deep linking.
  static const String customScheme = 'myapp';
}
