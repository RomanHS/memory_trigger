package com.example.memory_trigger

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class DatabaseHelper(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME    = "memory_trigger.db"
        const val DATABASE_VERSION = 6

        // ── Приоритеты ───────────────────────────────────────────────────────
        const val PRIORITY_HIGH   = 1
        const val PRIORITY_MEDIUM = 2
        const val PRIORITY_LOW    = 3

        // ── words ────────────────────────────────────────────────────────────
        const val TABLE_WORDS    = "words"
        const val COL_WORD_ID    = "id"
        const val COL_FOREIGN    = "foreign_word"
        const val COL_TRANSLATION= "translation"
        const val COL_CREATED_AT = "created_at"
        const val COL_WORD_TS    = "timestamp_ms"
        const val COL_PRIORITY   = "priority"

        // ── settings ─────────────────────────────────────────────────────────
        const val TABLE_SETTINGS        = "settings"
        const val COL_SETTING_KEY       = "key"
        const val COL_SETTING_VALUE     = "value"
        const val KEY_DELAY_SECONDS     = "delay_seconds"
        const val DEFAULT_DELAY_SECONDS = 5
        const val KEY_LOOP_COUNT        = "loop_count"
        const val DEFAULT_LOOP_COUNT    = 1
        const val KEY_GSHEET_LINK       = "gsheet_link"

        private const val TAG = "DatabaseHelper"

        /** Фиксированный ID уведомления — в системе всегда не более одного. */
        const val NOTIFICATION_ID = 1001

        @Volatile private var instance: DatabaseHelper? = null
        fun getInstance(context: Context): DatabaseHelper =
            instance ?: synchronized(this) {
                instance ?: DatabaseHelper(context).also { instance = it }
            }
    }

    private val createWords = """
        CREATE TABLE $TABLE_WORDS (
            $COL_WORD_ID     INTEGER PRIMARY KEY AUTOINCREMENT,
            $COL_FOREIGN     TEXT NOT NULL,
            $COL_TRANSLATION TEXT NOT NULL,
            $COL_CREATED_AT  TEXT NOT NULL,
            $COL_WORD_TS     INTEGER NOT NULL,
            $COL_PRIORITY    INTEGER NOT NULL DEFAULT $PRIORITY_HIGH
        )
    """.trimIndent()

    private val createSettings = """
        CREATE TABLE $TABLE_SETTINGS (
            $COL_SETTING_KEY   TEXT PRIMARY KEY,
            $COL_SETTING_VALUE TEXT NOT NULL
        )
    """.trimIndent()

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(createWords)
        db.execSQL(createSettings)
        db.execSQL("INSERT INTO $TABLE_SETTINGS VALUES ('$KEY_DELAY_SECONDS', '$DEFAULT_DELAY_SECONDS')")
        db.execSQL("INSERT INTO $TABLE_SETTINGS VALUES ('$KEY_LOOP_COUNT', '$DEFAULT_LOOP_COUNT')")
        Log.d(TAG, "Database v$DATABASE_VERSION created")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE_WORDS ($COL_WORD_ID INTEGER PRIMARY KEY AUTOINCREMENT, $COL_FOREIGN TEXT NOT NULL, $COL_TRANSLATION TEXT NOT NULL, $COL_CREATED_AT TEXT NOT NULL, $COL_WORD_TS INTEGER NOT NULL)")
        }
        if (oldVersion < 3) {
            db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE_SETTINGS ($COL_SETTING_KEY TEXT PRIMARY KEY, $COL_SETTING_VALUE TEXT NOT NULL)")
            db.execSQL("INSERT OR IGNORE INTO $TABLE_SETTINGS VALUES ('$KEY_DELAY_SECONDS', '$DEFAULT_DELAY_SECONDS')")
        }
        if (oldVersion < 4) {
            // Добавляем колонку priority; у существующих слов ставим HIGH по умолчанию
            db.execSQL("ALTER TABLE $TABLE_WORDS ADD COLUMN $COL_PRIORITY INTEGER NOT NULL DEFAULT $PRIORITY_HIGH")
            Log.d(TAG, "Migrated to v4: priority column added")
        }
        if (oldVersion < 5) {
            // Добавляем счетчик кругов в настройки
            db.execSQL("INSERT OR IGNORE INTO $TABLE_SETTINGS VALUES ('$KEY_LOOP_COUNT', '$DEFAULT_LOOP_COUNT')")
            Log.d(TAG, "Migrated to v5: loop_count added")
        }
        if (oldVersion < 6) {
            // Добавляем ссылку на гугл таблицу в настройки
            db.execSQL("INSERT OR IGNORE INTO $TABLE_SETTINGS VALUES ('$KEY_GSHEET_LINK', '')")
            Log.d(TAG, "Migrated to v6: gsheet_link added")
        }
    }

    // ── words: CRUD ────────────────────────────────────────────────────────────

    fun insertWord(foreignWord: String, translation: String, createdAt: String, timestampMs: Long): Long {
        val values = ContentValues().apply {
            put(COL_FOREIGN, foreignWord)
            put(COL_TRANSLATION, translation)
            put(COL_CREATED_AT, createdAt)
            put(COL_WORD_TS, timestampMs)
            put(COL_PRIORITY, PRIORITY_HIGH)
        }
        return writableDatabase.insertWithOnConflict(TABLE_WORDS, null, values, SQLiteDatabase.CONFLICT_IGNORE).also {
            Log.d(TAG, "Inserted word id=$it '$foreignWord'")
        }
    }

    /**
     * Массовая вставка слов.
     * Если слово уже есть (по иностранному слову), обновляем только перевод.
     * Приоритет не трогаем.
     */
    fun bulkInsertWords(words: List<Map<String, String>>): Int {
        val db = writableDatabase
        var importedCount = 0
        db.beginTransaction()
        try {
            val now = System.currentTimeMillis()
            val createdAt = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US).format(java.util.Date(now))
            
            for (wordMap in words) {
                val foreign = wordMap["foreign_word"] ?: continue
                val translation = wordMap["translation"] ?: ""
                
                // Проверяем существование
                db.query(TABLE_WORDS, arrayOf(COL_WORD_ID), "$COL_FOREIGN = ?", arrayOf(foreign), null, null, null).use { cursor ->
                    if (cursor.moveToFirst()) {
                        // Обновляем перевод
                        val id = cursor.getLong(0)
                        val values = ContentValues().apply { put(COL_TRANSLATION, translation) }
                        db.update(TABLE_WORDS, values, "$COL_WORD_ID = ?", arrayOf(id.toString()))
                    } else {
                        // Вставляем новое
                        val values = ContentValues().apply {
                            put(COL_FOREIGN, foreign)
                            put(COL_TRANSLATION, translation)
                            put(COL_CREATED_AT, createdAt)
                            put(COL_WORD_TS, now)
                            put(COL_PRIORITY, PRIORITY_HIGH)
                        }
                        db.insert(TABLE_WORDS, null, values)
                        importedCount++
                    }
                }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return importedCount
    }

    fun updateWord(wordId: Long, foreignWord: String, translation: String) {
        val values = ContentValues().apply {
            put(COL_FOREIGN, foreignWord)
            put(COL_TRANSLATION, translation)
        }
        writableDatabase.update(TABLE_WORDS, values, "$COL_WORD_ID = ?", arrayOf(wordId.toString()))
        Log.d(TAG, "Updated word id=$wordId")
    }

    fun deleteWord(wordId: Long) {
        writableDatabase.delete(TABLE_WORDS, "$COL_WORD_ID = ?", arrayOf(wordId.toString()))
        Log.d(TAG, "Deleted word id=$wordId")
    }

    fun updateWordPriority(wordId: Long, priority: Int) {
        val values = ContentValues().apply { put(COL_PRIORITY, priority) }
        writableDatabase.update(TABLE_WORDS, values, "$COL_WORD_ID = ?", arrayOf(wordId.toString()))
        Log.d(TAG, "Updated priority: wordId=$wordId priority=$priority")
    }

    fun getAllWords(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        readableDatabase.query(
            TABLE_WORDS,
            arrayOf(COL_WORD_ID, COL_FOREIGN, COL_TRANSLATION, COL_CREATED_AT, COL_WORD_TS, COL_PRIORITY),
            null, null, null, null, "$COL_WORD_TS DESC"
        ).use { c ->
            while (c.moveToNext()) result.add(wordFromCursor(c))
        }
        return result
    }

    /**
     * Следующее слово по ID с циклическим переходом.
     * Реализует логику приоритетов:
     * - Приоритет 1 (Высокий): каждый круг
     * - Приоритет 2 (Средний): каждый второй круг
     * - Приоритет 3 (Низкий): каждый третий круг
     *
     * Если после прохода слово не найдено, loop_count инкрементируется и поиск продолжается.
     */
    fun getNextWord(currentId: Long): Map<String, Any>? {
        var loopCount = getLoopCount()
        var searchId = currentId
        val db = readableDatabase

        // Безопасный предел поиска (чтобы не уйти в бесконечный цикл)
        for (pass in 1..20) {
            db.query(
                TABLE_WORDS,
                null,
                "$COL_WORD_ID > ?",
                arrayOf(searchId.toString()),
                null, null, "$COL_WORD_ID ASC"
            ).use { c ->
                while (c.moveToNext()) {
                    val word = wordFromCursor(c)
                    val priority = (word["priority"] as? Int) ?: PRIORITY_HIGH
                    
                    // Условие показа: номер круга кратен приоритету
                    if (loopCount % priority == 0) {
                        return word
                    }
                }
            }

            // Если дошли до конца — инкрементируем круг и начинаем с начала id=-1
            loopCount++
            setLoopCount(loopCount)
            searchId = -1L
        }

        // Если совсем ничего не нашли (например, пустая БД), пробуем взять хоть что-то
        db.query(TABLE_WORDS, null, null, null, null, null, "$COL_WORD_ID ASC", "1").use { c ->
            if (c.moveToFirst()) return wordFromCursor(c)
        }

        return null
    }

    private fun wordFromCursor(c: Cursor): Map<String, Any> {
        val result = mutableMapOf<String, Any>(
            "id"           to c.getLong(c.getColumnIndexOrThrow(COL_WORD_ID)),
            "foreign_word" to c.getString(c.getColumnIndexOrThrow(COL_FOREIGN)),
            "translation"  to c.getString(c.getColumnIndexOrThrow(COL_TRANSLATION))
        )
        val createdIdx  = c.getColumnIndex(COL_CREATED_AT)
        val tsIdx       = c.getColumnIndex(COL_WORD_TS)
        val priorityIdx = c.getColumnIndex(COL_PRIORITY)
        if (createdIdx  >= 0) result["created_at"]   = c.getString(createdIdx)
        if (tsIdx       >= 0) result["timestamp_ms"] = c.getLong(tsIdx)
        if (priorityIdx >= 0) result["priority"]     = c.getInt(priorityIdx)
        return result
    }

    // ── settings ───────────────────────────────────────────────────────────────

    fun getDelaySeconds(): Int {
        readableDatabase.query(TABLE_SETTINGS, arrayOf(COL_SETTING_VALUE),
            "$COL_SETTING_KEY = ?", arrayOf(KEY_DELAY_SECONDS), null, null, null
        ).use { c ->
            if (c.moveToFirst()) return c.getString(0).toIntOrNull() ?: DEFAULT_DELAY_SECONDS
        }
        return DEFAULT_DELAY_SECONDS
    }

    fun setDelaySeconds(seconds: Int) {
        val values = ContentValues().apply { put(COL_SETTING_VALUE, seconds.toString()) }
        val updated = writableDatabase.update(TABLE_SETTINGS, values,
            "$COL_SETTING_KEY = ?", arrayOf(KEY_DELAY_SECONDS))
        if (updated == 0) {
            writableDatabase.insert(TABLE_SETTINGS, null, ContentValues().apply {
                put(COL_SETTING_KEY, KEY_DELAY_SECONDS)
                put(COL_SETTING_VALUE, seconds.toString())
            })
        }
    }

    fun getLoopCount(): Int {
        readableDatabase.query(TABLE_SETTINGS, arrayOf(COL_SETTING_VALUE),
            "$COL_SETTING_KEY = ?", arrayOf(KEY_LOOP_COUNT), null, null, null
        ).use { c ->
            if (c.moveToFirst()) return c.getString(0).toIntOrNull() ?: DEFAULT_LOOP_COUNT
        }
        return DEFAULT_LOOP_COUNT
    }

    fun setLoopCount(count: Int) {
        val values = ContentValues().apply { put(COL_SETTING_VALUE, count.toString()) }
        val updated = writableDatabase.update(TABLE_SETTINGS, values,
            "$COL_SETTING_KEY = ?", arrayOf(KEY_LOOP_COUNT))
        if (updated == 0) {
            writableDatabase.insert(TABLE_SETTINGS, null, ContentValues().apply {
                put(COL_SETTING_KEY, KEY_LOOP_COUNT)
                put(COL_SETTING_VALUE, count.toString())
            })
        }
        Log.d(TAG, "Global loop count updated: $count")
    }

    fun getGSheetLink(): String {
        readableDatabase.query(TABLE_SETTINGS, arrayOf(COL_SETTING_VALUE),
            "$COL_SETTING_KEY = ?", arrayOf(KEY_GSHEET_LINK), null, null, null
        ).use { c ->
            if (c.moveToFirst()) return c.getString(0) ?: ""
        }
        return ""
    }

    fun setGSheetLink(link: String) {
        val values = ContentValues().apply { put(COL_SETTING_VALUE, link) }
        val updated = writableDatabase.update(TABLE_SETTINGS, values,
            "$COL_SETTING_KEY = ?", arrayOf(KEY_GSHEET_LINK))
        if (updated == 0) {
            writableDatabase.insert(TABLE_SETTINGS, null, ContentValues().apply {
                put(COL_SETTING_KEY, KEY_GSHEET_LINK)
                put(COL_SETTING_VALUE, link)
            })
        }
    }

    fun getAllSettings(): Map<String, String> {
        val result = mutableMapOf<String, String>()
        readableDatabase.query(TABLE_SETTINGS, null, null, null, null, null, null).use { c ->
            while (c.moveToNext())
                result[c.getString(c.getColumnIndexOrThrow(COL_SETTING_KEY))] =
                    c.getString(c.getColumnIndexOrThrow(COL_SETTING_VALUE))
        }
        return result
    }
}
