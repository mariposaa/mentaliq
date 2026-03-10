import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad Service - iOS rewarded ads are active.
class AdService {
  // iOS AdMob IDs (provided by user)
  static const String _iosRewardedAdUnitId = 'ca-app-pub-8177405180533300/7704210405';

  static bool _isInitialized = false;
  static bool _isAdLoading = false;
  static bool _isAdReady = false;
  static RewardedAd? _rewardedAd;

  static bool get isInitialized => _isInitialized;
  static bool get isAdReady => _isAdReady;

  static bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Initialize AdMob (iOS active, others fallback)
  static Future<void> initialize() async {
    try {
      if (_isIos) {
        await MobileAds.instance.initialize();
        _isInitialized = true;
        debugPrint('AdService: iOS AdMob initialized');
        await loadRewardedAd();
        return;
      }

      // Fallback for non-iOS platforms in this release
      _isInitialized = true;
      _isAdReady = true;
      debugPrint('AdService: Non-iOS fallback mode enabled');
    } catch (e) {
      debugPrint('AdService: Init error - $e');
    }
  }

  /// Load rewarded ad
  static Future<void> loadRewardedAd() async {
    if (_isAdLoading) return;
    _isAdLoading = true;
    _isAdReady = false;

    if (!_isIos) {
      _isAdLoading = false;
      _isAdReady = true;
      return;
    }

    await RewardedAd.load(
      adUnitId: _iosRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd?.dispose();
          _rewardedAd = ad;
          _isAdLoading = false;
          _isAdReady = true;
          debugPrint('AdService: iOS rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          _isAdReady = false;
          debugPrint('AdService: Rewarded load failed - $error');
        },
      ),
    );
  }

  /// Show rewarded ad and return true if reward earned
  static Future<bool> showRewardedAd() async {
    if (!_isIos) {
      // Fallback in non-iOS for now.
      return true;
    }

    if (_rewardedAd == null || !_isAdReady) {
      await loadRewardedAd();
      if (_rewardedAd == null) return false;
    }

    final completer = Completer<bool>();
    bool rewardEarned = false;
    final ad = _rewardedAd!;
    _rewardedAd = null;
    _isAdReady = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        loadRewardedAd();
        debugPrint('AdService: Failed to show rewarded - $error');
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
      },
    );

    return completer.future;
  }

  static bool isAdAvailable() {
    if (_isIos) return _isAdReady;
    return _isInitialized;
  }
}
