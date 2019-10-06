import 'dart:collection';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/hive_object.dart';
import 'package:hive/src/util/indexable_skip_list.dart';
import 'package:meta/meta.dart';

class KeyTransaction {
  final Keystore _keystore;
  final int _id;
  final List<dynamic> _addedKeys = [];
  final Map<dynamic, Frame> _deletedFrames = HashMap();

  KeyTransaction._(this._id, this._keystore);

  void commit() {
    if (_keystore.finishedTransactionId++ != _id) {
      throw HiveError('Could not commit key transaction. '
          'Please open an issue on GitHub.');
    }
  }

  void cancel() {
    commit();
    var keys = {..._addedKeys, ..._deletedFrames.keys};
    var transactions = List<KeyTransaction>();
    for (var key in keys) {
      var deletedFrame = _deletedFrames[key];
      var addedKey = _addedKeys.contains(key) ? key : null;

      for (var t in transactions) {
        if (t._addedKeys.contains(key) || t._deletedFrames.containsKey(key)) {
          if (deletedFrame != null) {
            t._deletedFrames[key] = deletedFrame;
          } else {
            t._deletedFrames.remove(key);
          }
          break;
        }
      }

      for (var t in transactions) {
        if (t.added.contains(key)) {
          shouldAdd = false;
          shouldDelete = false;
        } else if (t.deleted.containsKey(key)) {
          shouldAdd = false;
        }
      }

      if (shouldAdd) {
        _store.insert(key, canceled.deleted[key]);
      } else if (shouldDelete) {
        _store.delete(key);
      }
    }
  }
}

int _compareKeys(dynamic k1, dynamic k2) {
  if (k1.runtimeType == k2.runtimeType) {
    return (k1 as Comparable).compareTo(k2);
  } else {
    return k1 is int ? -1 : 1;
  }
}

class Keystore {
  final IndexableSkipList<dynamic, Frame> _store;

  @visibleForTesting
  int transactionId = 0;

  @visibleForTesting
  int finishedTransactionId = 0;

  var _deletedEntries = 0;
  var _autoIncrement = -1;

  Keystore([KeyComparator keyComparator])
      : _store = IndexableSkipList(keyComparator ?? _compareKeys);

  factory Keystore.debug(Iterable<Frame> frames,
      [KeyComparator keyComparator]) {
    var keystore = Keystore(keyComparator);
    for (var frame in frames) {
      keystore.add(frame);
    }
    return keystore;
  }

  int get deletedEntries => _deletedEntries;

  int get length => _store.length;

  Iterable<Frame> get frames => _store.values;

  void resetDeletedEntries() {
    _deletedEntries = 0;
  }

  int autoIncrement() {
    return ++_autoIncrement;
  }

  void updateAutoIncrement(int key) {
    if (key > _autoIncrement) {
      _autoIncrement = key;
    }
  }

  bool containsKey(dynamic key) {
    return _store.get(key) != null;
  }

  dynamic keyAt(int index) {
    var keys = _store.keys;
    var keyIndex = 0;
    for (var key in keys) {
      if (index == keyIndex) return key;
      keyIndex++;
    }
    return null;
  }

  Frame get(dynamic key) {
    return _store.get(key);
  }

  Frame getAt(int index) {
    return _store.getAt(index);
  }

  Iterable<dynamic> getKeys() {
    return _store.keys;
  }

  Iterable<dynamic> getValues() {
    return _store.values.map((e) => e.value);
  }

  void add(Frame frame) {
    var key = frame.key;
    if (key is int && key > _autoIncrement) {
      _autoIncrement = key;
    }
    var oldFrame = _store.insert(key, frame);
    if (oldFrame != null) {
      _deletedEntries++;
    }
  }

  void delete(dynamic key) {
    var deletedFrame = _store.delete(key);
    if (deletedFrame != null) {
      _deletedEntries++;
      if (deletedFrame.value is HiveObject) {
        unloadHiveObject(deletedFrame.value as HiveObject);
      }
    }
  }

  void beginAddTransaction(List<Frame> newFrames, Box box) {
    var transaction = _KeyTransaction();
    for (var frame in newFrames) {
      var key = frame.key;
      if (key is int && key > _autoIncrement) {
        _autoIncrement = key;
      }

      if (frame.value is HiveObject) {
        initHiveObject(key, frame.value as HiveObject, box);
      }

      var deletedFrame = _store.insert(key, frame);
      if (deletedFrame != null) {
        transaction.deleted[key] = deletedFrame;
        _deletedEntries++;

        if (deletedFrame.value is HiveObject) {
          unloadHiveObject(deletedFrame.value as HiveObject);
        }
      }

      transaction.added.add(key);
    }
    transactions.add(transaction);
  }

  void beginDeleteTransaction(Iterable<dynamic> keys) {
    var transaction = _KeyTransaction();
    for (var key in keys) {
      var deletedFrame = _store.delete(key);
      if (deletedFrame != null) {
        transaction.deleted[key] = deletedFrame;
        _deletedEntries++;

        if (deletedFrame.value is HiveObject) {
          unloadHiveObject(deletedFrame.value as HiveObject);
        }
      }
    }
    transactions.add(transaction);
  }

  void commitTransaction() {
    transactions.removeFirst();
  }

  void cancelTransaction() {
    var canceled = transactions.removeFirst();
  }

  void clear() {
    _store.clear();
    for (var frame in frames) {
      if (frame.value is HiveObject) {
        unloadHiveObject(frame.value as HiveObject);
      }
    }
    _deletedEntries = 0;
    transactions.clear();
  }
}
