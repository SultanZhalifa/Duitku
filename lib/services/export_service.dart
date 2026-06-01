import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Handles exporting CSV content via the platform share sheet.
///
/// On mobile/desktop the CSV is written to a temporary file and shared as an
/// attachment; on web (where there's no file system) the CSV is shared as text.
/// All errors surface as an [ExportException] so the UI can show a real message
/// rather than failing silently.
class ExportService {
  const ExportService();

  /// Shares [csv] as `duitku_export.csv`. Returns the share result status.
  Future<void> shareCsv(String csv) async {
    if (csv.trim().isEmpty) {
      throw const ExportException('There is no data to export yet.');
    }

    try {
      if (kIsWeb) {
        // No file system on web — share the CSV as plain text.
        await Share.share(csv, subject: 'Duitku export');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/duitku_export.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Duitku export',
      );
    } on ExportException {
      rethrow;
    } catch (e) {
      throw ExportException('Could not export data: $e');
    }
  }
}

/// A user-presentable error raised while exporting.
class ExportException implements Exception {
  const ExportException(this.message);
  final String message;

  @override
  String toString() => message;
}
