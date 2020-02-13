part of hive;

/// The main API interface of Hive. Available through the `Hive` constant.
abstract class HiveInterface implements TypeRegistry {
  /// Initialize Hive by giving it a home directory.
  ///
  /// (Not necessary in the browser)
  void init(String path);

  /// Opens a box.
  ///
  /// If the box is already open, the instance is returned and all provided
  /// parameters are being ignored.
  Future<Box<E>> openBox<E>(
    String name, {
    HiveCipher encryptionCipher,
    KeyComparator keyComparator,
    CompactionStrategy compactionStrategy,
    bool crashRecovery = true,
    String path,
    Uint8List bytes,
  });

  /// Opens a lazy box.
  ///
  /// If the box is already open, the instance is returned and all provided
  /// parameters are being ignored.
  Future<LazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher encryptionCipher,
    KeyComparator keyComparator,
    CompactionStrategy compactionStrategy,
    bool crashRecovery = true,
    String path,
  });

  Future<IsolateBox<E>> openIsolateBox<E>(
    String name, {
    bool lazy = false,
    HiveCipher encryptionCipher,
    KeyComparator keyComparator,
    CompactionStrategy compactionStrategy,
    bool crashRecovery = true,
    String path,
  });

  /// Returns a previously opened box.
  Box<E> box<E>(String name);

  /// Returns a previously opened lazy box.
  LazyBox<E> lazyBox<E>(String name);

  IsolateBox<E> isolateBox<E>(String name);

  /// Checks if a specific box is currently open.
  bool isBoxOpen(String name);

  /// Closes all open boxes.
  Future<void> close();

  Future<void> deleteBoxFromDisk(String nme);

  /// Deletes all currently open boxes from disk.
  ///
  /// The home directory will not be deleted.
  Future<void> deleteFromDisk();

  /// Generates a secure encryption key using the fortuna random algorithm.
  List<int> generateSecureKey();
}

abstract class KeyComparator {
  int compareKeys(dynamic key1, dynamic key2);
}

abstract class CompactionStrategy {
  bool shouldCompact(int entries, int deletedEntries);
}
