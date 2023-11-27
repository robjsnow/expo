// Copyright 2015-present 650 Industries. All rights reserved.

import ExpoModulesCore
import sqlite3

private typealias SQLiteColumnNames = [String]
private typealias SQLiteColumnValues = [Any]
private let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
private let MEMORY_DB_NAME = ":memory:"

public final class SQLiteModuleNext: Module {
  // Store unmanaged (SQLiteModuleNext, Database) pairs for sqlite callbacks,
  // will release the pair when `closeDatabase` is called.
  private var contextPairs = [Unmanaged<AnyObject>]()

  private static let lockQueue = DispatchQueue(label: "expo.modules.sqlite.lockQueue")
  private var cachedDatabases = [NativeDatabase]()
  private var cachedStatements = [NativeDatabase: [NativeStatement]]()
  private var hasListeners = false

  public func definition() -> ModuleDefinition {
    Name("ExpoSQLiteNext")

    Events("onDatabaseChange")

    OnStartObserving {
      hasListeners = true
    }

    OnStopObserving {
      hasListeners = false
    }

    OnDestroy {
      removeAllCachedDatabases().forEach {
        do {
          try closeDatabase($0)
        } catch {}
      }
    }

    AsyncFunction("deleteDatabaseAsync") { (databaseName: String) in
      try deleteDatabase(databaseName: databaseName)
    }
    Function("deleteDatabaseSync") { (databaseName: String) in
      try deleteDatabase(databaseName: databaseName)
    }

    // swiftlint:disable:next closure_body_length
    Class(NativeDatabase.self) {
      Constructor { (databaseName: String, options: OpenDatabaseOptions) -> NativeDatabase in
        guard let path = pathForDatabaseName(name: databaseName) else {
          throw DatabaseException()
        }

        // Try to find opened database for fast refresh
        if let cachedDb = findCachedDatabase(where: { $0.databaseName == databaseName && $0.openOptions == options && !options.useNewConnection }) {
          return cachedDb
        }

        var db: OpaquePointer?
        if sqlite3_open(path.absoluteString, &db) != SQLITE_OK {
          throw DatabaseException()
        }

        let database = NativeDatabase(db, databaseName: databaseName, openOptions: options)
        addCachedDatabase(database)
        return database
      }

      AsyncFunction("initAsync") { (database: NativeDatabase) in
        try initDb(database: database)
      }
      Function("initSync") { (database: NativeDatabase) in
        try initDb(database: database)
      }

      AsyncFunction("isInTransactionAsync") { (database: NativeDatabase) -> Bool in
        try maybeThrowForClosedDatabase(database)
        return sqlite3_get_autocommit(database.pointer) == 0
      }
      Function("isInTransactionSync") { (database: NativeDatabase) -> Bool in
        try maybeThrowForClosedDatabase(database)
        return sqlite3_get_autocommit(database.pointer) == 0
      }

      AsyncFunction("closeAsync") { (database: NativeDatabase) in
        removeCachedDatabase(of: database)
        try closeDatabase(database)
      }
      Function("closeSync") { (database: NativeDatabase) in
        removeCachedDatabase(of: database)
        try closeDatabase(database)
      }

      AsyncFunction("execAsync") { (database: NativeDatabase, source: String) in
        try exec(database: database, source: source)
      }
      Function("execSync") { (database: NativeDatabase, source: String) in
        try exec(database: database, source: source)
      }

      AsyncFunction("prepareAsync") { (database: NativeDatabase, statement: NativeStatement, source: String) in
        try prepareStatement(database: database, statement: statement, source: source)
      }
      Function("prepareSync") { (database: NativeDatabase, statement: NativeStatement, source: String) in
        try prepareStatement(database: database, statement: statement, source: source)
      }
    }

    // swiftlint:disable:next closure_body_length
    Class(NativeStatement.self) {
      Constructor {
        return NativeStatement()
      }

      AsyncFunction("arrayRunAsync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) -> [String: Int] in
        return try arrayRun(statement: statement, database: database, bindParams: bindParams)
      }
      Function("arrayRunSync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) -> [String: Int] in
        return try arrayRun(statement: statement, database: database, bindParams: bindParams)
      }

      AsyncFunction("objectRunAsync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) -> [String: Int] in
        return try objectRun(statement: statement, database: database, bindParams: bindParams)
      }
      Function("objectRunSync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) -> [String: Int] in
        return try objectRun(statement: statement, database: database, bindParams: bindParams)
      }

      AsyncFunction("arrayGetAsync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) -> SQLiteColumnValues? in
        return try arrayGet(statement: statement, database: database, bindParams: bindParams)
      }
      Function("arrayGetSync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) -> SQLiteColumnValues? in
        return try arrayGet(statement: statement, database: database, bindParams: bindParams)
      }

      AsyncFunction("objectGetAsync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) -> SQLiteColumnValues? in
        return try objectGet(statement: statement, database: database, bindParams: bindParams)
      }
      Function("objectGetSync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) -> SQLiteColumnValues? in
        return try objectGet(statement: statement, database: database, bindParams: bindParams)
      }

      AsyncFunction("arrayGetAllAsync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) -> [SQLiteColumnValues] in
        return try arrayGetAll(statement: statement, database: database, bindParams: bindParams)
      }
      Function("arrayGetAllSync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) -> [SQLiteColumnValues] in
        return try arrayGetAll(statement: statement, database: database, bindParams: bindParams)
      }

      AsyncFunction("objectGetAllAsync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) -> [SQLiteColumnValues] in
        return try objectGetAll(statement: statement, database: database, bindParams: bindParams)
      }
      Function("objectGetAllSync") { (statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) -> [SQLiteColumnValues] in
        return try objectGetAll(statement: statement, database: database, bindParams: bindParams)
      }

      AsyncFunction("getColumnNamesAsync") { (statement: NativeStatement) -> SQLiteColumnNames in
        return try getColumnNames(statement: statement)
      }
      Function("getColumnNamesSync") { (statement: NativeStatement) -> SQLiteColumnNames in
        return try getColumnNames(statement: statement)
      }

      AsyncFunction("resetAsync") { (statement: NativeStatement, database: NativeDatabase) in
        try reset(statement: statement, database: database)
      }
      Function("resetSync") { (statement: NativeStatement, database: NativeDatabase) in
        try reset(statement: statement, database: database)
      }

      AsyncFunction("finalizeAsync") { (statement: NativeStatement, database: NativeDatabase) in
        try finalize(statement: statement, database: database)
      }
      Function("finalizeSync") { (statement: NativeStatement, database: NativeDatabase) in
        try finalize(statement: statement, database: database)
      }
    }
  }

  private func pathForDatabaseName(name: String) -> URL? {
    if name == MEMORY_DB_NAME {
      return URL(string: name)
    }
    guard let fileSystem = appContext?.fileSystem else {
      return nil
    }

    let directory = URL(string: fileSystem.documentDirectory)?.appendingPathComponent("SQLite")
    fileSystem.ensureDirExists(withPath: directory?.absoluteString)

    return directory?.appendingPathComponent(name)
  }

  private func initDb(database: NativeDatabase) throws {
    try maybeThrowForClosedDatabase(database)
    if database.openOptions.enableCRSQLite {
      crsqlite_init_from_swift(database.pointer)
    }
    if database.openOptions.enableChangeListener {
      addUpdateHook(database)
    }
  }

  private func exec(database: NativeDatabase, source: String) throws {
    try maybeThrowForClosedDatabase(database)
    var error: UnsafeMutablePointer<CChar>?
    let ret = sqlite3_exec(database.pointer, source, nil, nil, &error)
    if ret != SQLITE_OK, let error = error {
      let errorString = String(cString: error)
      sqlite3_free(error)
      throw SQLiteErrorException(errorString)
    }
  }

  private func prepareStatement(database: NativeDatabase, statement: NativeStatement, source: String) throws {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    if sqlite3_prepare_v2(database.pointer, source, Int32(source.count), &statement.pointer, nil) != SQLITE_OK {
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    maybeAddCachedStatement(database: database, statement: statement)
  }

  private func arrayRun(statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) throws -> [String: Int] {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    for (index, param) in bindParams.enumerated() {
      try bindStatementParam(statement: statement, with: param, at: Int32(index + 1))
    }
    let ret = sqlite3_step(statement.pointer)
    if ret != SQLITE_ROW && ret != SQLITE_DONE {
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    return [
      "lastInsertRowId": Int(sqlite3_last_insert_rowid(database.pointer)),
      "changes": Int(sqlite3_changes(database.pointer))
    ]
  }

  private func objectRun(statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) throws -> [String: Int] {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    for (name, param) in bindParams {
      let index = sqlite3_bind_parameter_index(statement.pointer, name.cString(using: .utf8))
      if index > 0 {
        try bindStatementParam(statement: statement, with: param, at: index)
      }
    }
    let ret = sqlite3_step(statement.pointer)
    if ret != SQLITE_ROW && ret != SQLITE_DONE {
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    return [
      "lastInsertRowId": Int(sqlite3_last_insert_rowid(database.pointer)),
      "changes": Int(sqlite3_changes(database.pointer))
    ]
  }

  private func arrayGet(statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) throws -> SQLiteColumnValues? {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    for (index, param) in bindParams.enumerated() {
      try bindStatementParam(statement: statement, with: param, at: Int32(index + 1))
    }
    let ret = sqlite3_step(statement.pointer)
    if ret == SQLITE_ROW {
      return try getColumnValues(statement: statement)
    }
    if ret != SQLITE_DONE {
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    return nil
  }

  private func objectGet(statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) throws -> SQLiteColumnValues? {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    for (name, param) in bindParams {
      let index = sqlite3_bind_parameter_index(statement.pointer, name.cString(using: .utf8))
      if index > 0 {
        try bindStatementParam(statement: statement, with: param, at: index)
      }
    }
    let ret = sqlite3_step(statement.pointer)
    if ret == SQLITE_ROW {
      return try getColumnValues(statement: statement)
    }
    if ret != SQLITE_DONE {
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    return nil
  }

  private func arrayGetAll(statement: NativeStatement, database: NativeDatabase, bindParams: [Any]) throws -> [SQLiteColumnValues] {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    for (index, param) in bindParams.enumerated() {
      try bindStatementParam(statement: statement, with: param, at: Int32(index + 1))
    }
    var columnValuesList: [SQLiteColumnValues] = []
    while true {
      let ret = sqlite3_step(statement.pointer)
      if ret == SQLITE_ROW {
        columnValuesList.append(try getColumnValues(statement: statement))
        continue
      } else if ret == SQLITE_DONE {
        break
      }
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    return columnValuesList
  }

  private func objectGetAll(statement: NativeStatement, database: NativeDatabase, bindParams: [String: Any]) throws -> [SQLiteColumnValues] {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    for (name, param) in bindParams {
      let index = sqlite3_bind_parameter_index(statement.pointer, name.cString(using: .utf8))
      if index > 0 {
        try bindStatementParam(statement: statement, with: param, at: index)
      }
    }
    var columnValuesList: [SQLiteColumnValues] = []
    while true {
      let ret = sqlite3_step(statement.pointer)
      if ret == SQLITE_ROW {
        columnValuesList.append(try getColumnValues(statement: statement))
        continue
      } else if ret == SQLITE_DONE {
        break
      }
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    return columnValuesList
  }

  private func reset(statement: NativeStatement, database: NativeDatabase) throws {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    if sqlite3_reset(statement.pointer) != SQLITE_OK {
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
  }

  private func finalize(statement: NativeStatement, database: NativeDatabase) throws {
    try maybeThrowForClosedDatabase(database)
    try maybeThrowForFinalizedStatement(statement)
    maybeRemoveCachedStatement(database: database, statement: statement)
    if sqlite3_finalize(statement.pointer) != SQLITE_OK {
      throw SQLiteErrorException(convertSqlLiteErrorToString(database))
    }
    statement.isFinalized = true
  }

  private func convertSqlLiteErrorToString(_ db: NativeDatabase) -> String {
    let code = sqlite3_errcode(db.pointer)
    let message = String(cString: sqlite3_errmsg(db.pointer), encoding: .utf8) ?? ""
    return "Error code \(code): \(message)"
  }

  private func closeDatabase(_ db: NativeDatabase) throws {
    try maybeThrowForClosedDatabase(db)
    for removedStatement in maybeRemoveAllCachedStatements(database: db) {
      sqlite3_finalize(removedStatement.pointer)
    }

    if db.openOptions.enableCRSQLite {
      sqlite3_exec(db.pointer, "SELECT crsql_finalize()", nil, nil, nil)
    }
    let ret = sqlite3_close(db.pointer)
    db.isClosed = true

    if let index = contextPairs.firstIndex(where: {
      guard let pair = $0.takeUnretainedValue() as? (SQLiteModuleNext, NativeDatabase) else {
        return false
      }
      if pair.1.sharedObjectId != db.sharedObjectId {
        return false
      }
      $0.release()
      return true
    }) {
      contextPairs.remove(at: index)
    }

    if ret != SQLITE_OK {
      throw SQLiteErrorException(convertSqlLiteErrorToString(db))
    }
  }

  private func deleteDatabase(databaseName: String) throws {
    if findCachedDatabase(where: { $0.databaseName == databaseName }) != nil {
      throw DeleteDatabaseException(databaseName)
    }

    if databaseName == MEMORY_DB_NAME {
      return
    }
    guard let path = pathForDatabaseName(name: databaseName) else {
      throw Exceptions.FileSystemModuleNotFound()
    }

    if !FileManager.default.fileExists(atPath: path.absoluteString) {
      throw DatabaseNotFoundException(databaseName)
    }

    do {
      try FileManager.default.removeItem(atPath: path.absoluteString)
    } catch {
      throw DeleteDatabaseFileException(databaseName)
    }
  }

  private func addUpdateHook(_ database: NativeDatabase) {
    let contextPair = Unmanaged.passRetained(((self, database) as AnyObject))
    contextPairs.append(contextPair)
    // swiftlint:disable:next multiline_arguments
    sqlite3_update_hook(database.pointer, { obj, action, databaseName, tableName, rowId in
      guard let obj,
        let tableName,
        let pair = Unmanaged<AnyObject>.fromOpaque(obj).takeUnretainedValue() as? (SQLiteModuleNext, NativeDatabase) else {
        return
      }
      let selfInstance = pair.0
      let database = pair.1
      let dbFilePath = sqlite3_db_filename(database.pointer, databaseName)
      if selfInstance.hasListeners, let databaseName, let dbFilePath {
        selfInstance.sendEvent("onDatabaseChange", [
          "databaseName": String(cString: UnsafePointer(databaseName)),
          "dbFilePath": String(cString: UnsafePointer(dbFilePath)),
          "tableName": String(cString: UnsafePointer(tableName)),
          "rowId": rowId,
          "typeId": SQLAction.fromCode(value: action)
        ])
      }
    },
    contextPair.toOpaque())
  }

  private func getColumnNames(statement: NativeStatement) throws -> SQLiteColumnNames {
    try maybeThrowForFinalizedStatement(statement)
    let columnCount = Int(sqlite3_column_count(statement.pointer))
    var columnNames: SQLiteColumnNames = Array(repeating: "", count: columnCount)
    for i in 0..<columnCount {
      columnNames[i] = String(cString: sqlite3_column_name(statement.pointer, Int32(i)))
    }
    return columnNames
  }

  private func getColumnValues(statement: NativeStatement) throws -> SQLiteColumnValues {
    try maybeThrowForFinalizedStatement(statement)
    let columnCount = Int(sqlite3_column_count(statement.pointer))
    var columnValues: SQLiteColumnValues = Array(repeating: 0, count: columnCount)
    for i in 0..<columnCount {
      columnValues[i] = try getColumnValue(statement: statement, at: Int32(i))
    }
    return columnValues
  }

  @inline(__always)
  private func getColumnValue(statement: NativeStatement, at index: Int32) throws -> Any {
    let instance = statement.pointer
    let type = sqlite3_column_type(instance, index)

    switch type {
    case SQLITE_INTEGER:
      return sqlite3_column_int64(instance, index)
    case SQLITE_FLOAT:
      return sqlite3_column_double(instance, index)
    case SQLITE_TEXT:
      guard let text = sqlite3_column_text(instance, index) else {
        throw InvalidConvertibleException("Null text")
      }
      return String(cString: text)
    case SQLITE_BLOB:
      guard let blob = sqlite3_column_blob(instance, index) else {
        throw InvalidConvertibleException("Null blob")
      }
      let size = sqlite3_column_bytes(instance, index)
      return Data(bytes: blob, count: Int(size))
    case SQLITE_NULL:
      return NSNull()
    default:
      throw InvalidConvertibleException("Unsupported column type: \(type)")
    }
  }

  private func bindStatementParam(statement: NativeStatement, with param: Any, at index: Int32) throws {
    let instance = statement.pointer
    switch param {
    case Optional<Any>.none:
      sqlite3_bind_null(instance, index)
    case _ as NSNull:
      sqlite3_bind_null(instance, index)
    case let param as Int64:
      sqlite3_bind_int64(instance, index, Int64(param))
    case let param as Double:
      sqlite3_bind_double(instance, index, param)
    case let param as String:
      sqlite3_bind_text(instance, index, param, -1, SQLITE_TRANSIENT)
    case let param as Data:
      _ = param.withUnsafeBytes {
        sqlite3_bind_blob(instance, index, $0.baseAddress, Int32(param.count), SQLITE_TRANSIENT)
      }
    case let param as Bool:
      sqlite3_bind_int(instance, index, param ? 1 : 0)
    default:
      throw InvalidConvertibleException("Unsupported parameter type: \(type(of: param))")
    }
  }

  private func maybeThrowForClosedDatabase(_ database: NativeDatabase) throws {
    if database.isClosed {
      throw AccessClosedResourceException()
    }
  }

  private func maybeThrowForFinalizedStatement(_ statement: NativeStatement) throws {
    if statement.isFinalized {
      throw AccessClosedResourceException()
    }
  }

  // MARK: - cachedDatabases managements

  private func addCachedDatabase(_ database: NativeDatabase) {
    Self.lockQueue.sync {
      cachedDatabases.append(database)
    }
  }

  @discardableResult
  private func removeCachedDatabase(of database: NativeDatabase) -> NativeDatabase? {
    return Self.lockQueue.sync {
      if let index = cachedDatabases.firstIndex(of: database) {
        let database = cachedDatabases[index]
        cachedDatabases.remove(at: index)
        return database
      }
      return nil
    }
  }

  private func findCachedDatabase(where predicate: (NativeDatabase) -> Bool) -> NativeDatabase? {
    return Self.lockQueue.sync {
      if let database = cachedDatabases.first(where: predicate) {
        return database
      }
      return nil
    }
  }

  private func removeAllCachedDatabases() -> [NativeDatabase] {
    return Self.lockQueue.sync {
      let databases = cachedDatabases
      cachedDatabases.removeAll()
      return databases
    }
  }

  // MARK: - cachedStatements managements

  private func maybeAddCachedStatement(database: NativeDatabase, statement: NativeStatement) {
    if !database.openOptions.finalizeUnusedStatementsBeforeClosing {
      return
    }
    Self.lockQueue.sync {
      if cachedStatements[database] != nil {
        cachedStatements[database]?.append(statement)
      } else {
        cachedStatements[database] = [statement]
      }
    }
  }

  private func maybeRemoveCachedStatement(database: NativeDatabase, statement: NativeStatement) {
    if !database.openOptions.finalizeUnusedStatementsBeforeClosing {
      return
    }
    Self.lockQueue.sync {
      if let index = cachedStatements[database]?.firstIndex(of: statement) {
        cachedStatements[database]?.remove(at: index)
      }
    }
  }

  private func maybeRemoveAllCachedStatements(database: NativeDatabase) -> [NativeStatement] {
    if !database.openOptions.finalizeUnusedStatementsBeforeClosing {
      return []
    }
    return Self.lockQueue.sync {
      if let statements = cachedStatements[database] {
        cachedStatements.removeValue(forKey: database)
        return statements
      }
      return []
    }
  }
}
