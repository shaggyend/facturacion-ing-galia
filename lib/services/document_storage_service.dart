import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:facturacion_ing_galia/models/saved_document.dart';

/// Persistence contract for locally stored quotes and invoices.
abstract class DocumentStorage {
  /// Loads all saved documents from local storage.
  Future<List<SavedDocument>> loadDocuments();

  /// Replaces the full persisted collection of [documents].
  Future<void> saveDocuments(List<SavedDocument> documents);

  /// Inserts or updates [document] in storage and returns the updated list.
  Future<List<SavedDocument>> upsertDocument(SavedDocument document) async {
    final current = List<SavedDocument>.from(await loadDocuments());
    final index = current.indexWhere((item) => item.id == document.id);
    if (index >= 0) {
      current[index] = document;
    } else {
      current.add(document);
    }
    await saveDocuments(current);
    return current;
  }

  /// Removes the document with [id] from storage and returns the updated list.
  Future<List<SavedDocument>> deleteDocument(String id) async {
    final current = await loadDocuments();
    final updated = current.where((item) => item.id != id).toList();
    await saveDocuments(updated);
    return updated;
  }
}

/// Cross-platform local persistence backed by [SharedPreferences].
class SharedPreferencesDocumentStorage extends DocumentStorage {
  SharedPreferencesDocumentStorage({
    this.storageKey = defaultStorageKey,
    this.preferences,
  });

  static const String defaultStorageKey = 'ing_galia_saved_documents_v1';

  final String storageKey;
  final SharedPreferences? preferences;

  Future<SharedPreferences> _resolvePreferences() async {
    return preferences ?? await SharedPreferences.getInstance();
  }

  @override
  Future<List<SavedDocument>> loadDocuments() async {
    try {
      final prefs = await _resolvePreferences();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return const <SavedDocument>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <SavedDocument>[];
      }

      final result = <SavedDocument>[];
      for (final item in decoded) {
        if (item is Map) {
          try {
            result.add(
              SavedDocument.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (error) {
            debugPrint('Omitiendo documento corrupto en almacenamiento: $error');
          }
        }
      }
      return result;
    } catch (error) {
      debugPrint('Error cargando documentos guardados: $error');
      return const <SavedDocument>[];
    }
  }

  @override
  Future<void> saveDocuments(List<SavedDocument> documents) async {
    final prefs = await _resolvePreferences();
    final encoded = jsonEncode(documents.map((doc) => doc.toJson()).toList());
    final ok = await prefs.setString(storageKey, encoded);
    if (!ok) {
      throw StateError('No se pudo guardar en el almacenamiento local.');
    }
  }
}
