//
//  DatabaseManager.swift
//  Budget to 0
//
//  SQLite database with templates + monthly transactions + cached balances + auto-migration
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
        migrateDatabase()
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
        // Templates table with date fields
        let createTemplatesTable = """
            CREATE TABLE IF NOT EXISTS bill_templates (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                amount REAL NOT NULL,
                isIncome INTEGER NOT NULL,
                recurrenceFrequency TEXT NOT NULL,
                category TEXT NOT NULL,
                notes TEXT,
                createdAt REAL NOT NULL,
                dueDay INTEGER,
                startDate REAL,
                semiMonthlyDay1 INTEGER,
                semiMonthlyDay2 INTEGER
            );
        """
        
        // Transactions table
        let createTransactionsTable = """
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                templateId TEXT,
                month INTEGER NOT NULL,
                year INTEGER NOT NULL,
                title TEXT NOT NULL,
                amount REAL NOT NULL,
                isIncome INTEGER NOT NULL,
                isPaid INTEGER NOT NULL,
                dueDate REAL NOT NULL,
                actualPaymentDate REAL,
                displayOrder INTEGER NOT NULL,
                category TEXT NOT NULL,
                notes TEXT,
                createdAt REAL NOT NULL
            );
        """
        
        // Settings table
        let createSettingsTable = """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """
        
        // Month balances cache table
        let createMonthBalancesTable = """
            CREATE TABLE IF NOT EXISTS month_balances (
                month INTEGER NOT NULL,
                year INTEGER NOT NULL,
                ending_balance REAL NOT NULL,
                last_updated REAL NOT NULL,
                PRIMARY KEY (month, year)
            );
        """
        
        executeSQL(createTemplatesTable)
        executeSQL(createTransactionsTable)
        executeSQL(createSettingsTable)
        executeSQL(createMonthBalancesTable)
    }
    
    private func migrateDatabase() {
        print("🔄 Checking if migration needed...")
        
        let query = "PRAGMA table_info(bill_templates);"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Could not check table schema")
            return
        }
        
        var hasDueDayColumn = false
        var hasStartDateColumn = false
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let columnName = String(cString: sqlite3_column_text(statement, 1))
            if columnName == "dueDay" {
                hasDueDayColumn = true
            }
            if columnName == "startDate" {
                hasStartDateColumn = true
            }
        }
        
        sqlite3_finalize(statement)
        
        if !hasDueDayColumn || !hasStartDateColumn {
            print("⚠️ OLD SCHEMA DETECTED - Dropping and recreating tables...")
            
            executeSQL("DROP TABLE IF EXISTS transactions;")
            executeSQL("DROP TABLE IF EXISTS bill_templates;")
            executeSQL("DROP TABLE IF EXISTS settings;")
            executeSQL("DROP TABLE IF EXISTS month_balances;")
            
            print("✅ Old tables dropped")
            
            createTables()
            
            print("✅ New schema created - migration complete!")
        } else {
            print("✅ Schema is up to date")
        }
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                // Success
            } else {
                print("❌ SQL execution failed: \(sql)")
            }
        } else {
            print("❌ SQL preparation failed: \(sql)")
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Template Operations
    
    func saveTemplate(_ template: BillTemplate) -> Bool {
        print("💾 Saving template: \(template.title)")
        
        let insertQuery = """
            INSERT INTO bill_templates (id, title, amount, isIncome, recurrenceFrequency, category, notes, createdAt, dueDay, startDate, semiMonthlyDay1, semiMonthlyDay2)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing insert template")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (template.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (template.title as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 3, template.amount)
        sqlite3_bind_int(statement, 4, template.isIncome ? 1 : 0)
        sqlite3_bind_text(statement, 5, (template.recurrenceFrequency.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (template.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 7, (template.notes as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 8, template.createdAt.timeIntervalSince1970)
        
        // Bind optional date fields
        if let dueDay = template.dueDay {
            sqlite3_bind_int(statement, 9, Int32(dueDay))
        } else {
            sqlite3_bind_null(statement, 9)
        }
        
        if let startDate = template.startDate {
            sqlite3_bind_double(statement, 10, startDate.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        if let day1 = template.semiMonthlyDay1 {
            sqlite3_bind_int(statement, 11, Int32(day1))
        } else {
            sqlite3_bind_null(statement, 11)
        }
        
        if let day2 = template.semiMonthlyDay2 {
            sqlite3_bind_int(statement, 12, Int32(day2))
        } else {
            sqlite3_bind_null(statement, 12)
        }
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Template saved")
            syncDatabase()
        }
        
        return result
    }
    
    func updateTemplate(_ template: BillTemplate) -> Bool {
        print("💾 Updating template: \(template.title)")
        
        let updateQuery = """
            UPDATE bill_templates SET
                title = ?,
                amount = ?,
                isIncome = ?,
                recurrenceFrequency = ?,
                category = ?,
                notes = ?,
                dueDay = ?,
                startDate = ?,
                semiMonthlyDay1 = ?,
                semiMonthlyDay2 = ?
            WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing update template")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (template.title as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 2, template.amount)
        sqlite3_bind_int(statement, 3, template.isIncome ? 1 : 0)
        sqlite3_bind_text(statement, 4, (template.recurrenceFrequency.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (template.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (template.notes as NSString).utf8String, -1, nil)
        
        if let dueDay = template.dueDay {
            sqlite3_bind_int(statement, 7, Int32(dueDay))
        } else {
            sqlite3_bind_null(statement, 7)
        }
        
        if let startDate = template.startDate {
            sqlite3_bind_double(statement, 8, startDate.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        if let day1 = template.semiMonthlyDay1 {
            sqlite3_bind_int(statement, 9, Int32(day1))
        } else {
            sqlite3_bind_null(statement, 9)
        }
        
        if let day2 = template.semiMonthlyDay2 {
            sqlite3_bind_int(statement, 10, Int32(day2))
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        sqlite3_bind_text(statement, 11, (template.id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Template updated")
            syncDatabase()
        }
        
        return result
    }
    
    func deleteTemplate(id: UUID) -> Bool {
        print("🗑️ Deleting template: \(id.uuidString)")
        
        let deleteQuery = "DELETE FROM bill_templates WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            syncDatabase()
        }
        
        return result
    }
    
    func loadTemplates() -> [BillTemplate] {
        var templates: [BillTemplate] = []
        let query = "SELECT * FROM bill_templates;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing load templates")
            return []
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let idString = String(cString: sqlite3_column_text(statement, 0))
            let title = String(cString: sqlite3_column_text(statement, 1))
            let amount = sqlite3_column_double(statement, 2)
            let isIncome = sqlite3_column_int(statement, 3) == 1
            let recurrenceFrequencyString = String(cString: sqlite3_column_text(statement, 4))
            let categoryString = String(cString: sqlite3_column_text(statement, 5))
            let notes = String(cString: sqlite3_column_text(statement, 6))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
            
            let dueDay: Int? = sqlite3_column_type(statement, 8) != SQLITE_NULL ?
                Int(sqlite3_column_int(statement, 8)) : nil
            
            let startDate: Date? = sqlite3_column_type(statement, 9) != SQLITE_NULL ?
                Date(timeIntervalSince1970: sqlite3_column_double(statement, 9)) : nil
            
            let semiMonthlyDay1: Int? = sqlite3_column_type(statement, 10) != SQLITE_NULL ?
                Int(sqlite3_column_int(statement, 10)) : nil
            
            let semiMonthlyDay2: Int? = sqlite3_column_type(statement, 11) != SQLITE_NULL ?
                Int(sqlite3_column_int(statement, 11)) : nil
            
            let template = BillTemplate(
                id: UUID(uuidString: idString) ?? UUID(),
                title: title,
                amount: amount,
                isIncome: isIncome,
                recurrenceFrequency: RecurrenceFrequency(rawValue: recurrenceFrequencyString) ?? .monthly,
                category: TransactionCategory(rawValue: categoryString) ?? .other,
                notes: notes,
                createdAt: createdAt,
                dueDay: dueDay,
                startDate: startDate,
                semiMonthlyDay1: semiMonthlyDay1,
                semiMonthlyDay2: semiMonthlyDay2
            )
            
            templates.append(template)
        }
        
        sqlite3_finalize(statement)
        print("✅ Loaded \(templates.count) templates")
        
        return templates
    }
    
    // MARK: - Transaction Operations
    
    func saveTransaction(_ transaction: Transaction) -> Bool {
        print("💾 Saving transaction: \(transaction.title) for \(transaction.month)/\(transaction.year)")
        
        let insertQuery = """
            INSERT INTO transactions (id, templateId, month, year, title, amount, isIncome, isPaid, 
                                     dueDate, actualPaymentDate, displayOrder, category, notes, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing insert transaction")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (transaction.id.uuidString as NSString).utf8String, -1, nil)
        
        if let templateId = transaction.templateId {
            sqlite3_bind_text(statement, 2, (templateId.uuidString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        
        sqlite3_bind_int(statement, 3, Int32(transaction.month))
        sqlite3_bind_int(statement, 4, Int32(transaction.year))
        sqlite3_bind_text(statement, 5, (transaction.title as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 6, transaction.amount)
        sqlite3_bind_int(statement, 7, transaction.isIncome ? 1 : 0)
        sqlite3_bind_int(statement, 8, transaction.isPaid ? 1 : 0)
        sqlite3_bind_double(statement, 9, transaction.dueDate.timeIntervalSince1970)
        
        if let paymentDate = transaction.actualPaymentDate {
            sqlite3_bind_double(statement, 10, paymentDate.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        sqlite3_bind_int(statement, 11, Int32(transaction.displayOrder))
        sqlite3_bind_text(statement, 12, (transaction.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 13, (transaction.notes as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 14, transaction.createdAt.timeIntervalSince1970)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Transaction saved")
            syncDatabase()
        }
        
        return result
    }
    
    func updateTransaction(_ transaction: Transaction) -> Bool {
        print("💾 Updating transaction: \(transaction.title)")
        
        let updateQuery = """
            UPDATE transactions SET
                title = ?,
                amount = ?,
                isPaid = ?,
                dueDate = ?,
                actualPaymentDate = ?,
                displayOrder = ?,
                category = ?,
                notes = ?
            WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing update transaction")
            return false
        }
        
        sqlite3_bind_text(statement, 1, (transaction.title as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 2, transaction.amount)
        sqlite3_bind_int(statement, 3, transaction.isPaid ? 1 : 0)
        sqlite3_bind_double(statement, 4, transaction.dueDate.timeIntervalSince1970)
        
        if let paymentDate = transaction.actualPaymentDate {
            sqlite3_bind_double(statement, 5, paymentDate.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        sqlite3_bind_int(statement, 6, Int32(transaction.displayOrder))
        sqlite3_bind_text(statement, 7, (transaction.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 8, (transaction.notes as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 9, (transaction.id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Transaction updated")
            syncDatabase()
        }
        
        return result
    }
    
    func deleteTransaction(id: UUID) -> Bool {
        print("🗑️ Deleting transaction: \(id.uuidString)")
        
        let deleteQuery = "DELETE FROM transactions WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            syncDatabase()
        }
        
        return result
    }
    
    func cacheMonthBalance(month: Int, year: Int, balance: Double) {
        print("💾 Caching balance for \(month)/\(year): \(balance)")
        
        var beginStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, "BEGIN IMMEDIATE TRANSACTION", -1, &beginStatement, nil) == SQLITE_OK {
            sqlite3_step(beginStatement)
            sqlite3_finalize(beginStatement)
        }
        
        let insertQuery = """
            INSERT OR REPLACE INTO month_balances (month, year, ending_balance, last_updated)
            VALUES (?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing cache insert")
            if let errorPointer = sqlite3_errmsg(db) {
                let errorMessage = String(cString: errorPointer)
                print("❌ SQLite Error: \(errorMessage)")
            }
            return
        }
        
        sqlite3_bind_int(statement, 1, Int32(month))
        sqlite3_bind_int(statement, 2, Int32(year))
        sqlite3_bind_double(statement, 3, balance)
        sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Cached balance for \(month)/\(year)")
            
            var commitStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "COMMIT", -1, &commitStatement, nil) == SQLITE_OK {
                sqlite3_step(commitStatement)
                sqlite3_finalize(commitStatement)
            }
            
            syncDatabase()
        } else {
            print("❌ Failed to cache balance")
            if let errorPointer = sqlite3_errmsg(db) {
                let errorMessage = String(cString: errorPointer)
                print("❌ SQLite Error: \(errorMessage)")
            }
        }
    }
    
    func loadTransactionsForMonth(month: Int, year: Int) -> [Transaction] {
        var transactions: [Transaction] = []
        let query = "SELECT * FROM transactions WHERE month = ? AND year = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing load transactions for month")
            return []
        }
        
        sqlite3_bind_int(statement, 1, Int32(month))
        sqlite3_bind_int(statement, 2, Int32(year))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let idString = String(cString: sqlite3_column_text(statement, 0))
            
            let templateIdString: String?
            if sqlite3_column_type(statement, 1) != SQLITE_NULL {
                templateIdString = String(cString: sqlite3_column_text(statement, 1))
            } else {
                templateIdString = nil
            }
            
            let month = Int(sqlite3_column_int(statement, 2))
            let year = Int(sqlite3_column_int(statement, 3))
            let title = String(cString: sqlite3_column_text(statement, 4))
            let amount = sqlite3_column_double(statement, 5)
            let isIncome = sqlite3_column_int(statement, 6) == 1
            let isPaid = sqlite3_column_int(statement, 7) == 1
            let dueDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
            
            let actualPaymentDate: Date?
            if sqlite3_column_type(statement, 9) != SQLITE_NULL {
                actualPaymentDate = Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
            } else {
                actualPaymentDate = nil
            }
            
            let displayOrder = Int(sqlite3_column_int(statement, 10))
            let categoryString = String(cString: sqlite3_column_text(statement, 11))
            let notes = String(cString: sqlite3_column_text(statement, 12))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 13))
            
            let transaction = Transaction(
                id: UUID(uuidString: idString) ?? UUID(),
                templateId: templateIdString != nil ? UUID(uuidString: templateIdString!) : nil,
                month: month,
                year: year,
                title: title,
                amount: amount,
                isIncome: isIncome,
                isPaid: isPaid,
                dueDate: dueDate,
                actualPaymentDate: actualPaymentDate,
                displayOrder: displayOrder,
                category: TransactionCategory(rawValue: categoryString) ?? .other,
                notes: notes,
                createdAt: createdAt
            )
            
            transactions.append(transaction)
        }
        
        sqlite3_finalize(statement)
        print("✅ Loaded \(transactions.count) transactions for \(month)/\(year)")
        
        return transactions
    }
    
    // MARK: - Month Balance Cache Operations
    
    func saveMonthBalance(month: Int, year: Int, endingBalance: Double) -> Bool {
        print("💾 Saving month balance: \(month)/\(year) = \(endingBalance)")
        
        let insertQuery = """
            INSERT OR REPLACE INTO month_balances (month, year, ending_balance, last_updated)
            VALUES (?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing save month balance")
            return false
        }
        
        sqlite3_bind_int(statement, 1, Int32(month))
        sqlite3_bind_int(statement, 2, Int32(year))
        sqlite3_bind_double(statement, 3, endingBalance)
        sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            syncDatabase()
        }
        
        return result
    }
    
    func loadMonthBalance(month: Int, year: Int) -> Double? {
        let query = "SELECT ending_balance FROM month_balances WHERE month = ? AND year = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        sqlite3_bind_int(statement, 1, Int32(month))
        sqlite3_bind_int(statement, 2, Int32(year))
        
        var balance: Double?
        if sqlite3_step(statement) == SQLITE_ROW {
            balance = sqlite3_column_double(statement, 0)
            print("✅ Loaded cached balance for \(month)/\(year): \(balance ?? 0)")
        }
        
        sqlite3_finalize(statement)
        return balance
    }
    
    func invalidateMonthBalance(month: Int, year: Int) -> Bool {
        print("🗑️ Invalidating month balance cache for \(month)/\(year)")
        
        let deleteQuery = "DELETE FROM month_balances WHERE month = ? AND year = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_int(statement, 1, Int32(month))
        sqlite3_bind_int(statement, 2, Int32(year))
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            syncDatabase()
        }
        
        return result
    }
    
    func invalidateMonthBalanceFrom(month: Int, year: Int) -> Bool {
        print("🗑️ Invalidating all month balance caches from \(month)/\(year) onward")
        
        let targetYearMonth = year * 12 + month
        
        let deleteQuery = """
            DELETE FROM month_balances 
            WHERE (year * 12 + month) >= ?;
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_int(statement, 1, Int32(targetYearMonth))
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            syncDatabase()
        }
        
        return result
    }
    
    // MARK: - Settings Operations
    
    func saveSetting(key: String, value: String) -> Bool {
        let insertQuery = "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?);"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (value as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            syncDatabase()
        }
        
        return result
    }
    
    func loadSetting(key: String) -> String? {
        let query = "SELECT value FROM settings WHERE key = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
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
        }
    }
    
    func getEarliestTransactionDate() -> (month: Int, year: Int)? {
        let query = """
            SELECT MIN(year) as min_year, MIN(month) as min_month
            FROM transactions
            WHERE year = (SELECT MIN(year) FROM transactions);
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error getting earliest transaction")
            return nil
        }
        
        var result: (month: Int, year: Int)?
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let year = Int(sqlite3_column_int(statement, 0))
            let month = Int(sqlite3_column_int(statement, 1))
            
            if year > 0 && month > 0 {
                result = (month: month, year: year)
                print("✅ Earliest transaction: \(month)/\(year)")
            } else {
                print("⚠️ No transactions found in database")
            }
        } else {
            print("⚠️ No transactions found in database")
        }
        
        sqlite3_finalize(statement)
        return result
    }
    
    func deleteTransactionsBeforeMonth(month: Int, year: Int) {
        let targetYearMonth = year * 12 + month
        
        let deleteQuery = """
            DELETE FROM transactions 
            WHERE (year * 12 + month) < ?;
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        sqlite3_bind_int(statement, 1, Int32(targetYearMonth))
        
        if sqlite3_step(statement) == SQLITE_DONE {
            syncDatabase()
            print("✅ Deleted all transactions before \(month)/\(year)")
        }
        
        sqlite3_finalize(statement)
    }
    
    func clearBalanceCache() {
        executeSQL("DELETE FROM month_balances;")
        syncDatabase()
        print("✅ Balance cache cleared")
    }
    
    func updateTransactionDisplayOrder(id: UUID, displayOrder: Int) {
        print("🔄 Updating display order for \(id.uuidString) to \(displayOrder)")
        
        var beginStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, "BEGIN IMMEDIATE TRANSACTION", -1, &beginStatement, nil) == SQLITE_OK {
            sqlite3_step(beginStatement)
            sqlite3_finalize(beginStatement)
        }
        
        let updateQuery = """
            UPDATE transactions
            SET displayOrder = ?
            WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing display order update")
            return
        }
        
        sqlite3_bind_int(statement, 1, Int32(displayOrder))
        sqlite3_bind_text(statement, 2, (id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Updated display order")
            
            var commitStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "COMMIT", -1, &commitStatement, nil) == SQLITE_OK {
                sqlite3_step(commitStatement)
                sqlite3_finalize(commitStatement)
            }
            
            syncDatabase()
        } else {
            print("❌ Failed to update display order")
            
            var rollbackStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "ROLLBACK", -1, &rollbackStatement, nil) == SQLITE_OK {
                sqlite3_step(rollbackStatement)
                sqlite3_finalize(rollbackStatement)
            }
        }
    }
    
    func resetDatabase() {
        executeSQL("DELETE FROM transactions;")
        executeSQL("DELETE FROM bill_templates;")
        executeSQL("DELETE FROM settings;")
        executeSQL("DELETE FROM month_balances;")
        syncDatabase()
        print("✅ Database reset")
    }
    
    deinit {
        sqlite3_close(db)
    }
}
