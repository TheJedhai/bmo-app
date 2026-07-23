import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/account.dart';
import 'models/dedup_review.dart';
import 'models/summary.dart';
import 'models/transaction.dart';

class FinancesApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const FinancesApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() =>
      'FinancesApiException($statusCode, $errorCode): $message';
}

class FinancesClient {
  final http.Client _client;
  final String _baseUrl;

  FinancesClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // ============================================================
  // Accounts
  // ============================================================

  Future<List<Account>> listAccounts() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/finances/accounts'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // Summary
  // ============================================================

  Future<FinanceSummary> getSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = _formatDate(from);
    if (to != null) params['to'] = _formatDate(to);

    final uri = Uri.parse('$_baseUrl/api/v1/finances/summary')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await _client.get(uri);
    _ensureOk(response);
    return FinanceSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ============================================================
  // Transactions
  // ============================================================

  /// Retorna [results, total] — lista de transações e total de registros.
  Future<(List<Transaction>, int)> listTransactions({
    DateTime? from,
    DateTime? to,
    String? accountId,
    String? q,
    int pageSize = 50,
    int page = 1,
  }) async {
    final params = <String, String>{
      'page_size': pageSize.toString(),
      'page': page.toString(),
    };
    if (from != null) params['from'] = _formatDate(from);
    if (to != null) params['to'] = _formatDate(to);
    if (accountId != null) params['account_id'] = accountId;
    if (q != null && q.isNotEmpty) params['q'] = q;

    final uri = Uri.parse('$_baseUrl/api/v1/finances/transactions')
        .replace(queryParameters: params);

    final response = await _client.get(uri);
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>?)
            ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <Transaction>[];
    final total = decoded['total'] as int? ?? 0;
    return (results, total);
  }

  // ============================================================
  // Dedup Reviews
  // ============================================================

  Future<List<DedupReview>> listDedupReviews({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;

    final uri = Uri.parse('$_baseUrl/api/v1/finances/dedup-reviews')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => DedupReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveDedupReview(int id, {required String verdict}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/finances/dedup-reviews/$id/resolve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'verdict': verdict}),
    );
    _ensureOk(response);
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String errorCode = 'unknown';
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        errorCode = decoded['error'] as String? ?? 'unknown';
        message = decoded['message'] as String? ?? response.body;
      }
    } catch (_) {
      // corpo não é JSON
    }
    throw FinancesApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
