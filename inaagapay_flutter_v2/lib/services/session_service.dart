// lib/services/session_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child.dart';
import '../models/growth_record.dart';

class SessionService extends ChangeNotifier {
  static const String _childrenKey = 'inaagapay_children';
  static const String _recordsKey = 'inaagapay_growth_records';
  
  List<Child> _children = [];
  List<GrowthRecord> _records = [];
  Child? _selectedChild;

  List<Child> get children => _children;
  List<GrowthRecord> get records => _records;
  Child? get selectedChild => _selectedChild;

  SessionService() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load children
      final childrenJson = prefs.getString(_childrenKey);
      if (childrenJson != null) {
        final List<dynamic> decoded = json.decode(childrenJson);
        _children = decoded.map((item) => Child.fromJson(item)).toList();
      }

      // Load records
      final recordsJson = prefs.getString(_recordsKey);
      if (recordsJson != null) {
        final List<dynamic> decoded = json.decode(recordsJson);
        _records = decoded.map((item) => GrowthRecord.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading from storage: $e');
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save children
      final childrenJson = json.encode(_children.map((c) => c.toJson()).toList());
      await prefs.setString(_childrenKey, childrenJson);

      // Save records
      final recordsJson = json.encode(_records.map((r) => r.toJson()).toList());
      await prefs.setString(_recordsKey, recordsJson);
    } catch (e) {
      debugPrint('Error saving to storage: $e');
    }
  }

  Future<void> addChild(Child child) async {
    _children.add(child);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> updateChild(Child child) async {
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index != -1) {
      _children[index] = child;
      await _saveToStorage();
      notifyListeners();
    }
  }

  Future<void> deleteChild(String childId) async {
    _children.removeWhere((c) => c.id == childId);
    _records.removeWhere((r) => r.childId == childId);
    if (_selectedChild?.id == childId) {
      _selectedChild = null;
    }
    await _saveToStorage();
    notifyListeners();
  }

  void selectChild(Child? child) {
    _selectedChild = child;
    notifyListeners();
  }

  Future<void> addGrowthRecord(GrowthRecord record) async {
    _records.add(record);
    await _saveToStorage();
    notifyListeners();
  }

  List<GrowthRecord> getChildRecords(String childId) {
    return _records.where((r) => r.childId == childId).toList()
      ..sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
  }

  Future<void> clearAll() async {
    _children.clear();
    _records.clear();
    _selectedChild = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_childrenKey);
    await prefs.remove(_recordsKey);
    
    notifyListeners();
  }
}