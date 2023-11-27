/**
 * Result of a `runAsync` call.
 */
export interface SQLiteRunResult {
  /**
   * The last inserted row ID.
   */
  lastInsertRowId: number;

  /**
   * The number of rows affected.
   */
  changes: number;
}

/**
 * Bind parameters to the prepared statement.
 * You can either pass the parameters in the following forms:
 *
 * @example
 * - A single array for unnamed parameters.
 * ```ts
 * const statement = await db.prepareAsync('SELECT * FROM test WHERE value = ? AND intValue = ?');
 * await statement.getAsync(['test1', 789]);
 * ```
 *
 * @example
 * - Variadic arguments for unnamed parameters.
 * ```ts
 * const statement = await db.prepareAsync('SELECT * FROM test WHERE value = ? AND intValue = ?');
 * await statement.getAsync('test1', 789);
 * ```
 *
 * @example
 * - A single object for [named parameters](https://www.sqlite.org/lang_expr.html)
 *
 * We support multiple named parameter forms such as `:VVV`, `@VVV`, and `$VVV`. We recommend using `$VVV` because JavaScript allows using `$` in identifiers without escaping.
 * ```ts
 * const statement = await db.prepareAsync('SELECT * FROM test WHERE value = $value AND intValue = $intValue');
 * await statement.getAsync({ $value: 'test1', $intValue: 789 });
 * ```
 */
export type SQLiteBindValue = string | number | null | boolean;
export type SQLiteBindParams = Record<string, SQLiteBindValue> | SQLiteBindValue[];
export type SQLiteVariadicBindParams = SQLiteBindValue[];

export type SQLiteColumnNames = string[];
export type SQLiteColumnValues = any[];
type SQLiteAnyDatabase = any;

/**
 * A class that represents an instance of the SQLite statement.
 */
export declare class NativeStatement {
  //#region Asynchronous API

  public arrayRunAsync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): Promise<SQLiteRunResult>;
  public objectRunAsync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): Promise<SQLiteRunResult>;

  public arrayGetAsync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): Promise<SQLiteColumnValues | null | undefined>;
  public objectGetAsync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): Promise<SQLiteColumnValues | null | undefined>;

  public arrayGetAllAsync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): Promise<SQLiteColumnValues[]>;
  public objectGetAllAsync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): Promise<SQLiteColumnValues[]>;

  public getColumnNamesAsync(): Promise<SQLiteColumnNames>;

  public resetAsync(database: SQLiteAnyDatabase): Promise<void>;
  public finalizeAsync(database: SQLiteAnyDatabase): Promise<void>;

  //#endregion

  //#region Synchronous API

  public arrayRunSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteRunResult;
  public objectRunSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteRunResult;

  public arrayGetSync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): SQLiteColumnValues | null | undefined;
  public objectGetSync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): SQLiteColumnValues | null | undefined;

  public arrayGetAllSync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): SQLiteColumnValues[];
  public objectGetAllSync(
    database: SQLiteAnyDatabase,
    params: SQLiteBindParams
  ): SQLiteColumnValues[];

  public getColumnNamesSync(): string[];

  public resetSync(database: SQLiteAnyDatabase): void;
  public finalizeSync(database: SQLiteAnyDatabase): void;

  //#endregion
}
