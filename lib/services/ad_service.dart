// lib/services/ad_service.dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  // 1) private named constructor
  AdService._internal();

  // 2) singleton instance
  static final AdService instance = AdService._internal();

  static const _prefKey = 'lastAdShownMillis';
  static const _adUnitId = 'ca-app-pub-2912224344545278/5832765197';

  InterstitialAd? _interstitial;

  /// inizializza l’SDK e carica il primo interstitial
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadAd();
  }

  void _loadAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// mostra l’ad se è pronto e sono passati >30m dall’ultimo show
  Future<void> showAdIfAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_prefKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_interstitial != null && now - last > 2400 * 1000) {
      _interstitial!
        ..fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (_) {
            _interstitial?.dispose();
            _loadAd();
          },
          onAdFailedToShowFullScreenContent: (_, __) {
            _interstitial?.dispose();
            _loadAd();
          },
        )
        ..show();
      await prefs.setInt(_prefKey, now);
    }
  }
}


