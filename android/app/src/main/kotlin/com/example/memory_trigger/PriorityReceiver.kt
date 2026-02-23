package com.example.memory_trigger

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Обрабатывает нажатие на кнопки приоритета (Высокий / Средний / Низкий) в уведомлении.
 *
 * Действие:
 * 1. Обновляет приоритет текущего слова в БД
 * 2. Закрывает текущее уведомление
 * 3. Планирует следующее уведомление через AlarmManager (задержка из настроек)
 */
class PriorityReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PriorityReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val wordId   = intent.getLongExtra("wordId", -1L)
        val priority = intent.getIntExtra("priority", DatabaseHelper.PRIORITY_HIGH)

        val priorityName = when (priority) {
            DatabaseHelper.PRIORITY_HIGH   -> "Высокий"
            DatabaseHelper.PRIORITY_MEDIUM -> "Средний"
            DatabaseHelper.PRIORITY_LOW    -> "Низкий"
            else -> "?"
        }
        Log.d(TAG, "Priority button pressed: wordId=$wordId priority=$priority ($priorityName)")

        val db = DatabaseHelper.getInstance(context)

        // 1. Обновляем приоритет текущего слова
        if (wordId != -1L) {
            db.updateWordPriority(wordId, priority)
            // Уведомляем Флаттер, что данные изменились (приоритет обновился)
            MainActivity.sendEvent("db_changed")
        }

        // 2. Получаем следующее слово (с циклическим переходом)
        val nextWord = db.getNextWord(wordId) ?: run {
            Log.d(TAG, "No words in DB — nothing to schedule")
            return
        }
        val delaySeconds = db.getDelaySeconds()

        val nextWordId  = nextWord["id"] as Long
        val foreignWord = nextWord["foreign_word"] as String
        val translation = nextWord["translation"] as String

        Log.d(TAG, "Scheduling next: wordId=$nextWordId '$foreignWord' in ${delaySeconds}s")

        // 4. Планируем следующее уведомление
        NotificationHelper.scheduleRepeatingNotification(context, foreignWord, translation, nextWordId)
    }
}
