import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/recurring_rule.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/wallet_provider.dart';

/// A typed, user-presentable error from backup/restore.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Full, two-way backup of all app data to/from a versioned JSON document.
///
/// Unlike the read-only CSV export, a backup captures transactions, wallets,
/// budgets, recurring rules and the base currency, and can be restored on
/// another device. The document carries a [schemaVersion] so future format
/// changes can be migrated rather than rejected.
class BackupService {
  const BackupService();

  /// The current backup format version. Bump when the shape changes and add a
  /// migration branch in [_decode].
  static const int schemaVersion = 1;

  /// Builds the backup JSON string from the live providers.
  String buildBackupJson({
    required ExpenseProvider expenses,
    required WalletProvider wallets,
    required BudgetProvider budgets,
    required RecurringProvider recurring,
  }) {
    final doc = {
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Duitku',
      'baseCurrency': wallets.baseCurrencyCode,
      'wallets': wallets.toJsonList(),
      'transactions': expenses.toJsonList(),
      'budgets': budgets.toJson(),
      'recurring': recurring.toJsonList(),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  /// Writes the backup to a file and shares it (mobile/desktop), or shares the
  /// JSON as text on web where there's no file system.
  Future<void> exportBackup({
    required ExpenseProvider expenses,
    required WalletProvider wallets,
    required BudgetProvider budgets,
    required RecurringProvider recurring,
  }) async {
    final json = buildBackupJson(
      expenses: expenses,
      wallets: wallets,
      budgets: budgets,
      recurring: recurring,
    );
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final filename = 'duitku_backup_$stamp.json';

    try {
      if (kIsWeb) {
        await Share.share(json, subject: filename);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: filename,
      );
    } catch (e) {
      throw BackupException('Could not export backup: $e');
    }
  }

  /// Restores from a backup JSON string (e.g. pasted by the user or read from a
  /// shared file), replacing all current data. Validates and migrates the
  /// document before applying it, so bad input fails with a clear message
  /// rather than corrupting state.
  Future<void> restoreFromJson({
    required String json,
    required ExpenseProvider expenses,
    required WalletProvider wallets,
    required BudgetProvider budgets,
    required RecurringProvider recurring,
  }) async {
    final parsed = _decode(json);

    await wallets.replaceAll(parsed.wallets, parsed.baseCurrency);
    await expenses.replaceAll(parsed.transactions);
    await budgets.replaceFromJson(parsed.budgets);
    await recurring.replaceAll(parsed.recurring);
  }

  /// Parses and validates a backup document, applying any needed migrations.
  _ParsedBackup _decode(String raw) {
    final Map<String, dynamic> doc;
    try {
      doc = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('This file is not valid JSON.');
    }

    if (doc['app'] != 'Duitku' || doc['transactions'] == null) {
      throw const BackupException('This does not look like a Duitku backup.');
    }

    final version = (doc['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > schemaVersion) {
      throw BackupException(
        'This backup was made with a newer version of the app (v$version). '
        'Please update Duitku to restore it.',
      );
    }
    // v1 is the only schema so far; future versions add migration steps here.

    try {
      final wallets = (doc['wallets'] as List<dynamic>? ?? [])
          .map((e) => Wallet.fromJson(e as Map<String, dynamic>))
          .toList();
      final transactions = (doc['transactions'] as List<dynamic>)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
      final recurring = (doc['recurring'] as List<dynamic>? ?? [])
          .map((e) => RecurringRule.fromJson(e as Map<String, dynamic>))
          .toList();
      final budgets = (doc['budgets'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble()));

      return _ParsedBackup(
        baseCurrency: doc['baseCurrency'] as String? ?? 'IDR',
        wallets: wallets,
        transactions: transactions,
        recurring: recurring,
        budgets: budgets,
      );
    } catch (e) {
      throw BackupException('The backup file is corrupted: $e');
    }
  }
}

class _ParsedBackup {
  const _ParsedBackup({
    required this.baseCurrency,
    required this.wallets,
    required this.transactions,
    required this.recurring,
    required this.budgets,
  });

  final String baseCurrency;
  final List<Wallet> wallets;
  final List<Transaction> transactions;
  final List<RecurringRule> recurring;
  final Map<String, double> budgets;
}
