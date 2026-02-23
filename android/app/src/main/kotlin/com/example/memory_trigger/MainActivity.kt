package com.example.memory_trigger

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL    = "com.example.memory_trigger/notifications"
        const val DB_CHANNEL = "com.example.memory_trigger/database"
        const val EVENT_CHANNEL = "com.example.memory_trigger/events"
        const val CHANNEL_ID   = "memory_trigger_channel"
        const val CHANNEL_NAME = "Memory Trigger"

        private var eventSink: EventChannel.EventSink? = null
        private var instance: MainActivity? = null

        fun sendEvent(event: String) {
            instance?.runOnUiThread {
                eventSink?.success(event)
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        
        // Восстанавливаем цикл уведомлений при запуске приложения
        NotificationHelper.restoreCycle(this)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        // ── EventChannel ──────────────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // ── MethodChannel: уведомления ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                    }
                    result.success(true)
                }
                "scheduleNotification" -> {
                    val title  = call.argument<String>("title")   ?: ""
                    val body   = call.argument<String>("body")    ?: ""
                    val wordId = (call.argument<Int>("word_id") ?: -1).toLong()
                    scheduleNotification(title, body, wordId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── MethodChannel: база данных ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DB_CHANNEL).setMethodCallHandler { call, result ->
            val db = DatabaseHelper.getInstance(this)
            when (call.method) {
                "getAllWords" -> {
                    val words = db.getAllWords()
                    val serializable = words.map { row ->
                        mapOf(
                            "id"           to (row["id"] as Long).toInt(),
                            "foreign_word" to row["foreign_word"],
                            "translation"  to row["translation"],
                            "created_at"   to row["created_at"],
                            "timestamp_ms" to (row["timestamp_ms"] as Long),
                            "priority"     to (row["priority"] as? Int ?: DatabaseHelper.PRIORITY_HIGH)
                        )
                    }
                    result.success(serializable)
                }
                "addWord" -> {
                    val foreignWord = call.argument<String>("foreign_word") ?: ""
                    val translation = call.argument<String>("translation")  ?: ""
                    val createdAt   = call.argument<String>("created_at")   ?: ""
                    val timestampMs = call.argument<Long>("timestamp_ms")   ?: System.currentTimeMillis()
                    val id = db.insertWord(foreignWord, translation, createdAt, timestampMs)
                    result.success(id.toInt())
                }
                "updateWord" -> {
                    val wordId      = (call.argument<Int>("id") ?: 0).toLong()
                    val foreignWord = call.argument<String>("foreign_word") ?: ""
                    val translation = call.argument<String>("translation")  ?: ""
                    db.updateWord(wordId, foreignWord, translation)
                    result.success(null)
                }
                "deleteWord" -> {
                    val wordId = (call.argument<Int>("id") ?: 0).toLong()
                    db.deleteWord(wordId)
                    result.success(null)
                }
                "updateWordPriority" -> {
                    val wordId   = (call.argument<Int>("id") ?: 0).toLong()
                    val priority = call.argument<Int>("priority") ?: DatabaseHelper.PRIORITY_HIGH
                    db.updateWordPriority(wordId, priority)
                    result.success(null)
                }
                "getSettings" -> {
                    result.success(mapOf(
                        "delay_seconds" to db.getDelaySeconds(),
                        "gsheet_link"   to db.getGSheetLink(),
                        "last_word_id"  to db.getLastWordId()
                    ))
                }
                "setDelaySeconds" -> {
                    val seconds = call.argument<Int>("seconds") ?: DatabaseHelper.DEFAULT_DELAY_SECONDS
                    db.setDelaySeconds(seconds)
                    
                    // Перепланируем текущее ожидающее уведомление с новой задержкой,
                    // чтобы пользователю не приходилось ждать старый длинный интервал.
                    NotificationHelper.restoreCycle(this)
                    
                    result.success(null)
                }
                "setGSheetLink" -> {
                    val link = call.argument<String>("link") ?: ""
                    db.setGSheetLink(link)
                    result.success(null)
                }
                "setLastWordId" -> {
                    val id = (call.argument<Int>("id") ?: -1).toLong()
                    db.setLastWordId(id)
                    
                    // Если мы вручную меняем "последнее слово", полезно перепланировать уведомление
                    // если пользователь хочет, чтобы это слово СЛЕДУЮЩИМ.
                    // Но по логике getNextWord(currentId) возьмет слово ПОСЛЕ текущего.
                    // Если пользователь нажал "Сделать это слово активным", то уведомление должно быть С ЭТИМ словом?
                    // Обычно "активное" значит "последнее показанное".
                    result.success(null)
                }
                "scheduleImmediate" -> {
                    // Форсированный запуск уведомления для конкретного ID
                    val id = (call.argument<Int>("id") ?: -1).toLong()
                    val word = db.getWordById(id)
                    if (word != null) {
                        val fw = word["foreign_word"] as String
                        val tr = word["translation"]  as String
                        NotificationHelper.scheduleRepeatingNotification(this, fw, tr, id)
                    }
                    result.success(null)
                }
                "bulkAddWords" -> {
                    val wordsList = call.argument<List<Map<String, String>>>("words") ?: emptyList()
                    
                    // Проверяем, пуста ли база была ДО импорта
                    val wasEmpty = db.getAllWords().isEmpty()
                    
                    val importedCount = db.bulkInsertWords(wordsList)
                    
                    // Если была пуста и мы что-то импортировали — планируем первое уведомление
                    if (wasEmpty && importedCount > 0) {
                        val firstWord = db.getNextWord(-1L)
                        if (firstWord != null) {
                            val fw = firstWord["foreign_word"] as String
                            val tr = firstWord["translation"]  as String
                            val id = (firstWord["id"] as Long)
                            scheduleNotification(fw, tr, id)
                        }
                    }
                    
                    result.success(importedCount)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Memory Trigger Notifications"
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    /**
     * Планирует уведомление через AlarmManager.
     * - delaySeconds читается из БД (не от Flutter)
     * - Единственный request code = NOTIFICATION_ID → новый Alarm заменяет старый
     * - notificationId = NOTIFICATION_ID → одно уведомление в системе
     */
    private fun scheduleNotification(title: String, body: String, wordId: Long) {
        NotificationHelper.scheduleRepeatingNotification(this, title, body, wordId)
    }
}
