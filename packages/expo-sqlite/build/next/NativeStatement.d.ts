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
    arrayRunAsync(database: SQLiteAnyDatabase, params: SQLiteBindParams): Promise<SQLiteRunResult>;
    objectRunAsync(database: SQLiteAnyDatabase, params: SQLiteBindParams): Promise<SQLiteRunResult>;
    arrayGetAsync(database: SQLiteAnyDatabase, params: SQLiteBindParams): Promise<SQLiteColumnValues | null | undefined>;
    objectGetAsync(database: SQLiteAnyDatabase, params: SQLiteBindParams): Promise<SQLiteColumnValues | null | undefined>;
    arrayGetAllAsync(database: SQLiteAnyDatabase, params: SQLiteBindParams): Promise<SQLiteColumnValues[]>;
    objectGetAllAsync(database: SQLiteAnyDatabase, params: SQLiteBindParams): Promise<SQLiteColumnValues[]>;
    getColumnNamesAsync(): Promise<SQLiteColumnNames>;
    resetAsync(database: SQLiteAnyDatabase): Promise<void>;
    finalizeAsync(database: SQLiteAnyDatabase): Promise<void>;
    arrayRunSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteRunResult;
    objectRunSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteRunResult;
    arrayGetSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteColumnValues | null | undefined;
    objectGetSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteColumnValues | null | undefined;
    arrayGetAllSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteColumnValues[];
    objectGetAllSync(database: SQLiteAnyDatabase, params: SQLiteBindParams): SQLiteColumnValues[];
    getColumnNamesSync(): string[];
    resetSync(database: SQLiteAnyDatabase): void;
    finalizeSync(database: SQLiteAnyDatabase): void;
}
export {};
//# sourceMappingURL=NativeStatement.d.ts.map