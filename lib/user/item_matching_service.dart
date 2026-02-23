import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

// ==================== MATCHING CONFIGURATION ====================
class MatchingConfig {
  // Matching thresholds
  static const double highMatchThreshold = 70.0; // 70%+ creates notification
  static const double minMatchThreshold = 50.0;  // 50%+ considered

  // Field weights (must sum to 100)
  static const Map<String, double> weights = {
    'category': 20.0,              // Exact category match
    'itemName': 30.0,              // Item name similarity
    'itemDescription': 20.0,       // Description similarity
    'location': 15.0,              // Geographic proximity
    'locationDescription': 10.0,   // Location description similarity
    'dateTime': 5.0,               // Time proximity
  };

  // Location matching
  static const double maxDistanceMeters = 500.0; // Maximum distance

  // Time matching
  static const int maxTimeDiffHours = 72; // Maximum time difference (3 days)
}

// ==================== MATCHING SERVICE ====================
class ItemMatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _toDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final List<List<int>> matrix = List.generate(
      s2.length + 1,
          (i) => List.filled(s1.length + 1, 0),
    );

    for (int i = 0; i <= s2.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s1.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s2.length; i++) {
      for (int j = 1; j <= s1.length; j++) {
        if (s2[i - 1] == s1[j - 1]) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = [
            matrix[i - 1][j - 1] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j] + 1,
          ].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return matrix[s2.length][s1.length];
  }

  /// Calculate string similarity (0-100%)
  double _calculateStringSimilarity(String str1, String str2) {
    if (str1.isEmpty && str2.isEmpty) return 100.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final s1 = str1.toLowerCase().trim();
    final s2 = str2.toLowerCase().trim();

    if (s1 == s2) return 100.0;

    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    final distance = _levenshteinDistance(s1, s2);
    final similarity = ((maxLength - distance) / maxLength) * 100.0;

    return similarity.clamp(0.0, 100.0);
  }

  /// Calculate distance between two coordinates in meters (Haversine formula)
  double _calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double R = 6371000; // meters

    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  /// Check if two location circles overlap
  bool _doLocationsOverlap(
      double lat1,
      double lon1,
      double radius1,
      double lat2,
      double lon2,
      double radius2,
      ) {
    final distance = _calculateDistance(lat1, lon1, lat2, lon2);
    return distance <= (radius1 + radius2);
  }

  /// Calculate time difference in hours
  double _calculateTimeDifference(DateTime date1, DateTime date2) {
    final diffMs = (date1.difference(date2)).abs().inMilliseconds;
    return diffMs / (1000 * 60 * 60); // Convert to hours
  }

  /// Calculate match score between two items
  Map<String, dynamic> _calculateMatchScore(
      Map<String, dynamic> lostItem,
      Map<String, dynamic> foundItem,
      ) {
    final Map<String, double> breakdown = {};
    double totalScore = 0.0;

    // 1. Category Match (20 points)
    if (lostItem['category'] == foundItem['category']) {
      breakdown['category'] = MatchingConfig.weights['category']!;
      totalScore += MatchingConfig.weights['category']!;
    } else {
      breakdown['category'] = 0.0;
    }

    // 2. Item Name Similarity (30 points)
    final nameSimilarity = _calculateStringSimilarity(
      lostItem['itemName'] ?? '',
      foundItem['itemName'] ?? '',
    );
    breakdown['itemName'] = (nameSimilarity / 100.0) *
        MatchingConfig.weights['itemName']!;
    totalScore += breakdown['itemName']!;

    // 3. Description Similarity (20 points)
    final descSimilarity = _calculateStringSimilarity(
      lostItem['itemDescription'] ?? '',
      foundItem['itemDescription'] ?? '',
    );
    breakdown['itemDescription'] = (descSimilarity / 100.0) *
        MatchingConfig.weights['itemDescription']!;
    totalScore += breakdown['itemDescription']!;

    // 4. Location Match (15 points)
    final locationsOverlap = _doLocationsOverlap(
      _toDouble(lostItem['latitude'], 0.0),
      _toDouble(lostItem['longitude'], 0.0),
      _toDouble(lostItem['locationRadius'], 50.0),
      _toDouble(foundItem['latitude'], 0.0),
      _toDouble(foundItem['longitude'], 0.0),
      _toDouble(foundItem['locationRadius'], 50.0),
    );

    if (locationsOverlap) {
      final distance = _calculateDistance(
        _toDouble(lostItem['latitude'], 0.0),
        _toDouble(lostItem['longitude'], 0.0),
        _toDouble(foundItem['latitude'], 0.0),
        _toDouble(foundItem['longitude'], 0.0),
      );

      final locationScore = (1 - (distance / MatchingConfig.maxDistanceMeters))
          .clamp(0.0, 1.0) * MatchingConfig.weights['location']!;
      breakdown['location'] = locationScore;
      totalScore += locationScore;
    } else {
      breakdown['location'] = 0.0;
    }

    // 5. Location Description Similarity (10 points)
    final locDescSimilarity = _calculateStringSimilarity(
      lostItem['locationDescription'] ?? '',
      foundItem['locationDescription'] ?? '',
    );
    breakdown['locationDescription'] = (locDescSimilarity / 100.0) *
        MatchingConfig.weights['locationDescription']!;
    totalScore += breakdown['locationDescription']!;

    // 6. Time Proximity (5 points)
    final lostDate = (lostItem['lostDateTime'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final foundDate = (foundItem['foundDateTime'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final timeDiff = _calculateTimeDifference(lostDate, foundDate);

    if (timeDiff <= MatchingConfig.maxTimeDiffHours) {
      final timeScore = (1 - (timeDiff / MatchingConfig.maxTimeDiffHours))
          .clamp(0.0, 1.0) * MatchingConfig.weights['dateTime']!;
      breakdown['dateTime'] = timeScore;
      totalScore += timeScore;
    } else {
      breakdown['dateTime'] = 0.0;
    }

    return {
      'score': double.parse(totalScore.toStringAsFixed(1)),
      'breakdown': breakdown,
    };
  }

  /// Create a match notification in Firestore
  Future<void> _createMatchNotification({
    required String userId,
    required String matchType,
    required String itemId,
    required String matchedItemId,
    required double matchScore,
    required Map<String, double> breakdown,
    String? dropOffDeskId,
  }) async {
    try {
      await _firestore.collection('user_notifications').add({
        'userId': userId,
        'matchType': matchType,
        'itemId': itemId,
        'matchedItemId': matchedItemId,
        'matchScore': matchScore,
        'scoreBreakdown': breakdown,
        'dropOffDeskId': dropOffDeskId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Created notification for user $userId: $matchType item $itemId '
          'matched with $matchedItemId (score: $matchScore%)');
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  /// Search for matches when a lost item is submitted
  Future<void> matchLostItem(String lostItemId) async {
    try {
      print('Processing lost item $lostItemId for matching...');

      // Get the lost item
      final lostItemDoc = await _firestore
          .collection('lost_item_reports')
          .doc(lostItemId)
          .get();

      if (!lostItemDoc.exists) {
        print('Lost item $lostItemId not found');
        return;
      }

      final lostItem = lostItemDoc.data()!;

      // Only match if status is 'submitted'
      if (lostItem['reportStatus'] != 'submitted') {
        print('Lost item $lostItemId is not submitted, skipping match');
        return;
      }

      // Query all submitted found items
      final foundItemsSnapshot = await _firestore
          .collection('found_item_reports')
          .where('reportStatus', isEqualTo: 'submitted')
          .get();

      print('Found ${foundItemsSnapshot.docs.length} submitted found items');

      final List<Map<String, dynamic>> matches = [];

      // Calculate match score for each found item
      for (final foundDoc in foundItemsSnapshot.docs) {
        final foundItem = foundDoc.data();
        final foundItemId = foundDoc.id;

        final result = _calculateMatchScore(lostItem, foundItem);
        final score = result['score'] as double;
        final breakdown = result['breakdown'] as Map<String, double>;

        print('Match score between lost $lostItemId and found $foundItemId: '
            '$score%');

        if (score >= MatchingConfig.minMatchThreshold) {
          matches.add({
            'foundItemId': foundItemId,
            'score': score,
            'breakdown': breakdown,
            'dropOffDeskId': foundItem['dropOffDeskId'],
          });
        }
      }

      // Sort by score
      matches.sort((a, b) => (b['score'] as double)
          .compareTo(a['score'] as double));

      // Create notifications for high matches
      final highMatches = matches.where((m) =>
      (m['score'] as double) >= MatchingConfig.highMatchThreshold).toList();

      print('Found ${highMatches.length} high-confidence matches');

      for (final match in highMatches) {
        await _createMatchNotification(
          userId: lostItem['userId'],
          matchType: 'lost',
          itemId: lostItemId,
          matchedItemId: match['foundItemId'],
          matchScore: match['score'],
          breakdown: Map<String, double>.from(match['breakdown']),
          dropOffDeskId: match['dropOffDeskId'],
        );

        final foundItemDoc = await _firestore
            .collection('found_item_reports')
            .doc(match['foundItemId'])
            .get();

        if (foundItemDoc.exists) {
          final foundUserId = foundItemDoc.data()!['userId'];
          await _createMatchNotification(
            userId: foundUserId,
            matchType: 'found',
            itemId: match['foundItemId'],
            matchedItemId: lostItemId,
            matchScore: match['score'],
            breakdown: Map<String, double>.from(match['breakdown']),
            dropOffDeskId: match['dropOffDeskId'],
          );
          print('Created notification for found item user: $foundUserId');
        }
      }
    } catch (e) {
      print('Error in matchLostItem: $e');
    }
  }

  /// Search for matches when a found item is submitted
  Future<void> matchFoundItem(String foundItemId) async {
    try {
      print('Processing found item $foundItemId for matching...');

      // Get the found item
      final foundItemDoc = await _firestore
          .collection('found_item_reports')
          .doc(foundItemId)
          .get();

      if (!foundItemDoc.exists) {
        print('Found item $foundItemId not found');
        return;
      }

      final foundItem = foundItemDoc.data()!;

      // Only match if status is 'submitted'
      if (foundItem['reportStatus'] != 'submitted') {
        print('Found item $foundItemId is not submitted, skipping match');
        return;
      }

      // Query all submitted lost items
      final lostItemsSnapshot = await _firestore
          .collection('lost_item_reports')
          .where('reportStatus', isEqualTo: 'submitted')
          .get();

      print('Found ${lostItemsSnapshot.docs.length} submitted lost items');

      final List<Map<String, dynamic>> matches = [];

      // Calculate match score for each lost item
      for (final lostDoc in lostItemsSnapshot.docs) {
        final lostItem = lostDoc.data();
        final lostItemId = lostDoc.id;

        final result = _calculateMatchScore(lostItem, foundItem);
        final score = result['score'] as double;
        final breakdown = result['breakdown'] as Map<String, double>;

        print('Match score between found $foundItemId and lost $lostItemId: '
            '$score%');

        if (score >= MatchingConfig.minMatchThreshold) {
          matches.add({
            'lostItemId': lostItemId,
            'score': score,
            'breakdown': breakdown,
          });
        }
      }

      // Sort by score
      matches.sort((a, b) => (b['score'] as double)
          .compareTo(a['score'] as double));

      // Create notifications for high matches
      final highMatches = matches.where((m) =>
      (m['score'] as double) >= MatchingConfig.highMatchThreshold).toList();

      print('Found ${highMatches.length} high-confidence matches');

      for (final match in highMatches) {
        await _createMatchNotification(
          userId: foundItem['userId'],
          matchType: 'found',
          itemId: foundItemId,
          matchedItemId: match['lostItemId'],
          matchScore: match['score'],
          breakdown: Map<String, double>.from(match['breakdown']),
          dropOffDeskId: foundItem['dropOffDeskId'],
        );

        final lostItemDoc = await _firestore
            .collection('lost_item_reports')
            .doc(match['lostItemId'])
            .get();

        if (lostItemDoc.exists) {
          final lostUserId = lostItemDoc.data()!['userId'];
          await _createMatchNotification(
            userId: lostUserId,
            matchType: 'lost',
            itemId: match['lostItemId'],
            matchedItemId: foundItemId,
            matchScore: match['score'],
            breakdown: Map<String, double>.from(match['breakdown']),
            dropOffDeskId: foundItem['dropOffDeskId'],
          );
          print('Created notification for lost item user: $lostUserId');
        }
      }
    } catch (e) {
      print('Error in matchFoundItem: $e');
    }
  }
}