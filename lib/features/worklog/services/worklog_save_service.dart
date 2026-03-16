import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';

/// Eredmény típus a worklog mentéshez.
sealed class WorklogSaveResult {
  const WorklogSaveResult();
}

class WorklogSaveSuccess extends WorklogSaveResult {
  const WorklogSaveSuccess();
}

class WorklogSaveFailure extends WorklogSaveResult {
  final String message;
  const WorklogSaveFailure(this.message);
}

class WorklogSaveCancelled extends WorklogSaveResult {
  const WorklogSaveCancelled();
}

/// Worklog mentés: ütközésellenőrzés, trim párbeszéd, create és update.
class WorklogSaveService {
  const WorklogSaveService._();

  /// Új worklog létrehozása: validál, ütközés check, opcionális trim, add.
  static Future<WorklogSaveResult> createWorklog({
    required DocumentReference<Map<String, dynamic>> workspaceRef,
    required WorklogItemModel item,
    required BuildContext context,
  }) async {
    final validationError = _validateItem(item);
    if (validationError != null) {
      return WorklogSaveFailure(validationError);
    }

    final dateOnly = DateTime(item.date.year, item.date.month, item.date.day);
    final existingLogs = await _fetchWorklogsForDay(
      workspaceRef,
      item.employeeId,
      dateOnly,
    );

    WorklogItemModel itemToSave = item;
    WorklogItemModel? conflict = findOverlap(itemToSave, existingLogs);

    if (conflict != null) {
      final shouldTrim = await showConflictDialog(context, conflict);
      if (shouldTrim != true) {
        return const WorklogSaveCancelled();
      }
      itemToSave = applyTrim(itemToSave, conflict);
      if (itemToSave.workedMinutes <= 0) {
        return const WorklogSaveFailure(
          'Az új bejegyzés teljesen fedi a létezőt, nem vágható.',
        );
      }
    }

    try {
      await workspaceRef.collection('worklogs').add({
        ...itemToSave.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await workspaceRef.update({'updatedAt': FieldValue.serverTimestamp()});
      return const WorklogSaveSuccess();
    } catch (e) {
      return WorklogSaveFailure(e.toString());
    }
  }

  /// Meglévő worklog frissítése: validál, ütközés check (saját doc kizárva), trim, update.
  static Future<WorklogSaveResult> updateWorklog({
    required DocumentReference<Map<String, dynamic>> workspaceRef,
    required WorklogItemModel item,
    required BuildContext context,
  }) async {
    if (item.id.isEmpty) {
      return const WorklogSaveFailure('A bejegyzés azonosítója hiányzik.');
    }

    final validationError = _validateItem(item);
    if (validationError != null) {
      return WorklogSaveFailure(validationError);
    }

    final dateOnly = DateTime(item.date.year, item.date.month, item.date.day);
    final existingLogs = await _fetchWorklogsForDay(
      workspaceRef,
      item.employeeId,
      dateOnly,
    );

    WorklogItemModel itemToSave = item;
    WorklogItemModel? conflict = findOverlap(
      itemToSave,
      existingLogs,
      excludeDocumentId: item.id,
    );

    if (conflict != null) {
      final shouldTrim = await showConflictDialog(context, conflict);
      if (shouldTrim != true) {
        return const WorklogSaveCancelled();
      }
      itemToSave = applyTrim(itemToSave, conflict);
      if (itemToSave.workedMinutes <= 0) {
        return const WorklogSaveFailure(
          'A módosítás teljesen fedi a létező bejegyzést, nem vágható.',
        );
      }
    }

    try {
      final updateData =
          itemToSave.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
      await workspaceRef.collection('worklogs').doc(item.id).update(updateData);
      await workspaceRef.update({'updatedAt': FieldValue.serverTimestamp()});
      return const WorklogSaveSuccess();
    } catch (e) {
      return WorklogSaveFailure(e.toString());
    }
  }

  static String? _validateItem(WorklogItemModel item) {
    if (!item.endTime.isAfter(item.startTime)) {
      return 'A végidőnek későbbinek kell lennie a kezdőidőnél.';
    }
    return null;
  }

  static Future<List<WorklogItemModel>> _fetchWorklogsForDay(
    DocumentReference<Map<String, dynamic>> workspaceRef,
    String employeeId,
    DateTime dateOnly,
  ) async {
    final snapshot =
        await workspaceRef
            .collection('worklogs')
            .where('employeeId', isEqualTo: employeeId)
            .where('date', isEqualTo: dateOnly)
            .get();

    return snapshot.docs
        .map((doc) => WorklogItemModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Átfedést keres a megadott bejegyzés és a meglévők között.
  /// [excludeDocumentId]: szerkesztésnél a saját doc id, hogy ne magunkkal ütközzünk.
  static WorklogItemModel? findOverlap(
    WorklogItemModel newItem,
    List<WorklogItemModel> existing, {
    String? excludeDocumentId,
  }) {
    for (final log in existing) {
      if (excludeDocumentId != null && log.id == excludeDocumentId) {
        continue;
      }
      // Ha csak érintkeznek (vég = másik kezdete), nem számít átfedésnek
      if (newItem.endTime == log.startTime ||
          newItem.startTime == log.endTime) {
        continue;
      }
      if (newItem.startTime.isBefore(log.endTime) &&
          newItem.endTime.isAfter(log.startTime)) {
        return log;
      }
    }
    return null;
  }

  /// Az új bejegyzés kezdőidejét a meglévő végéhez igazítja.
  static WorklogItemModel applyTrim(
    WorklogItemModel newItem,
    WorklogItemModel existing,
  ) {
    final newStart = existing.endTime;
    return WorklogItemModel(
      id: newItem.id,
      employeeId: newItem.employeeId,
      projectId: newItem.projectId,
      description: newItem.description,
      date: newItem.date,
      workedMinutes: newItem.endTime.difference(newStart).inMinutes,
      startTime: newStart,
      endTime: newItem.endTime,
      breakMinutes: newItem.breakMinutes,
    );
  }

  /// Ütközés párbeszéd: "Automatikus vágás" vagy "Mégse".
  static Future<bool?> showConflictDialog(
    BuildContext context,
    WorklogItemModel conflict,
  ) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ütközés észlelhető'),
            content: Text(
              'Ez az időpont ütközik egy meglévő bejegyzéssel (${conflict.description}). '
              'Szeretnéd automatikusan módosítani a kezdési időpontot?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Mégse'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Automatikus vágás'),
              ),
            ],
          ),
    );
  }
}
