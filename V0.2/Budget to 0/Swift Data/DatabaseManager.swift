//
//  DatabaseManager.swift
//  Budget to 0
//
//  SQLite database management with immediate commits
//

import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dbPath = documentsPath.appendingPathComponent("budget.sqlite").path
        
        print("📂 Database path: \(dbPath)")
        
        openDatabase()
        createTables()
    }
    
    // MARK: - Database Setup
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("✅ Successfully opened database")
        } else {
            print("❌ Failed to open database")
        }
    }
    
    private func createTables() {
        let createTransactionsTable = """
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                amount REAL NOT NULL,
                isIncome INTEGER NOT NULL,
                isPaid INTEGER NOT NULL,
                dueDate REAL NOT NULL,
                isRecurring INTEGER NOT NULL,
                recurrenceFrequency TEXT NOT NULL,
                customRecurrenceDays TEXT,
                category TEXT NOT NULL,
                notes TEXT,
                createdAt REAL NOT NULL
            );
        """
        
        let createSettingsTable = """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """
        
        executeSQL(createTransactionsTable)
        executeSQL(createSettingsTable)
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ SQL executed successfully")
            } else {
                print("❌ SQL execution failed")
            }
        } else {
            print("❌ SQL preparation failed")
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Transaction Operations
    
    func saveTransaction(_ transaction: Transaction) -> Bool {
        print("💾 Saving transaction: \(transaction.title)")
        
        // Begin transaction
        var beginStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, "BEGIN IMMEDIATE TRANSACTION", -1, &beginStatement, nil) == SQLITE_OK {
            sqlite3_step(beginStatement)
            sqlite3_finalize(beginStatement)
        }
        
        let insertQuery = """
            INSERT INTO transactions (id, title, amount, isIncome, isPaid, dueDate, isRecurring, 
                                     recurrenceFrequency, customRecurrenceDays, category, notes, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing insert statement")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (transaction.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (transaction.title as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 3, transaction.amount)
        sqlite3_bind_int(statement, 4, transaction.isIncome ? 1 : 0)
        sqlite3_bind_int(statement, 5, transaction.isPaid ? 1 : 0)
        sqlite3_bind_double(statement, 6, transaction.dueDate.timeIntervalSince1970)
        sqlite3_bind_int(statement, 7, transaction.isRecurring ? 1 : 0)
        sqlite3_bind_text(statement, 8, (transaction.recurrenceFrequency.rawValue as NSString).utf8String, -1, nil)
        
        let daysJSON = try? JSONEncoder().encode(transaction.customRecurrenceDays)
        let daysString = daysJSON != nil ? String(data: daysJSON!, encoding: .utf8) : "[]"
        sqlite3_bind_text(statement, 9, (daysString! as NSString).utf8String, -1, nil)
        
        sqlite3_bind_text(statement, 10, (transaction.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 11, (transaction.notes as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 12, transaction.createdAt.timeIntervalSince1970)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Transaction saved to database")
            
            // Commit the transaction
            var commitStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "COMMIT", -1, &commitStatement, nil) == SQLITE_OK {
                sqlite3_step(commitStatement)
                sqlite3_finalize(commitStatement)
                print("✅ Transaction committed to disk")
            }
            
            // Force sync
            syncDatabase()
            
            return true
        } else {
            print("❌ Failed to save transaction")
            if let errorPointer = sqlite3_errmsg(db) {
                let errorMessage = String(cString: errorPointer)
                print("❌ SQLite Error: \(errorMessage)")
            }
            
            // Rollback on error
            var rollbackStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "ROLLBACK", -1, &rollbackStatement, nil) == SQLITE_OK {
                sqlite3_step(rollbackStatement)
                sqlite3_finalize(rollbackStatement)
            }
            
            return false
        }
    }
    
    func updateTransaction(_ transaction: Transaction) -> Bool {
        print("💾 Updating transaction: \(transaction.title)")
        
        // Begin transaction
        var beginStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, "BEGIN IMMEDIATE TRANSACTION", -1, &beginStatement, nil) == SQLITE_OK {
            sqlite3_step(beginStatement)
            sqlite3_finalize(beginStatement)
        }
        
        let updateQuery = """
            UPDATE transactions SET
                title = ?,
                amount = ?,
                isIncome = ?,
                isPaid = ?,
                dueDate = ?,
                isRecurring = ?,
                recurrenceFrequency = ?,
                customRecurrenceDays = ?,
                category = ?,
                notes = ?
            WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing update statement")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (transaction.title as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_int(statement, 3, transaction.isIncome ? 1 : 0)
        sqlite3_bind_int(statement, 4, transaction.isPaid ? 1 : 0)
        sqlite3_bind_double(statement, 5, transaction.dueDate.timeIntervalSince1970)
        sqlite3_bind_int(statement, 6, transaction.isRecurring ? 1 : 0)
        sqlite3_bind_text(statement, 7, (transaction.recurrenceFrequency.rawValue as NSString).utf8String, -1, nil)
        
        let daysJSON = try? JSONEncoder().encode(transaction.customRecurrenceDays)
        let daysString = daysJSON != nil ? String(data: daysJSON!, encoding: .utf8) : "[]"
        sqlite3_bind_text(statement, 8, (daysString! as NSString).utf8String, -1, nil)
        
        sqlite3_bind_text(statement, 9, (transaction.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 10, (transaction.notes as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 11, (transaction.id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Transaction updated in database")
            
            // Commit
            var commitStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "COMMIT", -1, &commitStatement, nil) == SQLITE_OK {
                sqlite3_step(commitStatement)
                sqlite3_finalize(commitStatement)
                print("✅ Update committed to disk")
            }
            
            // Force sync
            syncDatabase()
            
            return true
        } else {
            print("❌ Failed to update transaction")
            if let errorPointer = sqlite3_errmsg(db) {
                let errorMessage = String(cString: errorPointer)
                print("❌ SQLite Error: \(errorMessage)")
            }
            
            // Rollback
            var rollbackStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "ROLLBACK", -1, &rollbackStatement, nil) == SQLITE_OK {
                sqlite3_step(rollbackStatement)
                sqlite3_finalize(rollbackStatement)
            }
            
            return false
        }
    }
    
    func deleteTransaction(id: UUID) -> Bool {
        print("🗑️ Deleting transaction: \(id.uuidString)")
        
        // Begin transaction
        var beginStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, "BEGIN IMMEDIATE TRANSACTION", -1, &beginStatement, nil) == SQLITE_OK {
            sqlite3_step(beginStatement)
            sqlite3_finalize(beginStatement)
        }
        
        let deleteQuery = "DELETE FROM transactions WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing delete statement")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Transaction deleted from database")
            
            // Commit the transaction
            var commitStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "COMMIT", -1, &commitStatement, nil) == SQLITE_OK {
                sqlite3_step(commitStatement)
                sqlite3_finalize(commitStatement)
                print("✅ Delete committed to disk")
            }
            
            // Force sync
            syncDatabase()
            
            return true
        } else {
            print("❌ Failed to delete transaction")
            if let errorPointer = sqlite3_errmsg(db) {
                let errorMessage = String(cString: errorPointer)
                print("❌ SQLite Error: \(errorMessage)")
            }
            
            // Rollback on error
            var rollbackStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "ROLLBACK", -1, &rollbackStatement, nil) == SQLITE_OK {
                sqlite3_step(rollbackStatement)
                sqlite3_finalize(rollbackStatement)
            }
            
            return false
        }
    }
    
    func loadTransactions() -> [Transaction] {
        var transactions: [Transaction] = []
        let query = "SELECT * FROM transactions;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing load query")
            return []
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let idString = String(cString: sqlite3_column_text(statement, 0))
            let title = String(cString: sqlite3_column_text(statement, 1))
            let amount = sqlite3_column_double(statement, 2)
            let isIncome = sqlite3_column_int(statement, 3) == 1
            let isPaid = sqlite3_column_int(statement, 4) == 1
            let dueDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
            let isRecurring = sqlite3_column_int(statement, 6) == 1
            let recurrenceFrequencyString = String(cString: sqlite3_column_text(statement, 7))
            let customDaysString = String(cString: sqlite3_column_text(statement, 8))
            let categoryString = String(cString: sqlite3_column_text(statement, 9))
            let notes = String(cString: sqlite3_column_text(statement, 10))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 11))
            
            let customDays = (try? JSONDecoder().decode([Int].self, from: customDaysString.data(using: .utf8)!)) ?? []
            
            let transaction = Transaction(
                id: UUID(uuidString: idString) ?? UUID(),
                title: title,
                amount: amount,
                isIncome: isIncome,
                isPaid: isPaid,
                dueDate: dueDate,
                isRecurring: isRecurring,
                recurrenceFrequency: RecurrenceFrequency(rawValue: recurrenceFrequencyString) ?? .oneTime,
                customRecurrenceDays: customDays,
                category: TransactionCategory(rawValue: categoryString) ?? .other,
                notes: notes,
                createdAt: createdAt
            )
            
            transactions.append(transaction)
        }
        
        sqlite3_finalize(statement)
        print("✅ Loaded \(transactions.count) transactions from database")
        
        return transactions
    }
    
    // MARK: - Settings Operations
    
    func saveSetting(key: String, value: String) -> Bool {
        print("💾 Saving setting: \(key) = \(value)")
        
        // Begin transaction
        var beginStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, "BEGIN IMMEDIATE TRANSACTION", -1, &beginStatement, nil) == SQLITE_OK {
            sqlite3_step(beginStatement)
            sqlite3_finalize(beginStatement)
        }
        
        let insertQuery = "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?);"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing save setting")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (value as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Setting saved")
            
            // Commit
            var commitStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "COMMIT", -1, &commitStatement, nil) == SQLITE_OK {
                sqlite3_step(commitStatement)
                sqlite3_finalize(commitStatement)
            }
            
            syncDatabase()
            return true
        } else {
            print("❌ Failed to save setting")
            return false
        }
    }
    
    func loadSetting(key: String) -> String? {
        let query = "SELECT value FROM settings WHERE key = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing load setting")
            return nil
        }
        
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
        
        var value: String?
        if sqlite3_step(statement) == SQLITE_ROW {
            value = String(cString: sqlite3_column_text(statement, 0))
        }
        
        sqlite3_finalize(statement)
        return value
    }
    
    // MARK: - Utility Functions
    
    func syncDatabase() {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA wal_checkpoint(FULL)", -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
            sqlite3_finalize(statement)
            print("✅ Database synced to disk")
        }
    }
    
    func resetDatabase() {
        executeSQL("DELETE FROM transactions;")
        executeSQL("DELETE FROM settings;")
        syncDatabase()
        print("✅ Database reset")
    }
    
    deinit {
        sqlite3_close(db)
    }
}
