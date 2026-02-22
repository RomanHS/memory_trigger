package com.example.memory_trigger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Обрабатывает события завершения загрузки устройства (BOOT_COMPLETED)
 * и обновления приложения (MY_PACKAGE_REPLACED).
 * Служит для восстановления цикла уведомлений, если он был прерван.
 */
class RestorationReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "RestorationReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "RestorationReceiver triggered with action: ${action}")

        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val db = DatabaseHelper.getInstance(context)
            val lastWordId = db.getLastWordId()

            if (lastWordId != -1L) {
                val word = db.getWordById(lastWordId)
                if (word != null) {
                    val title = word["foreign_word"] as? String ?: ""
                    val body  = word["translation"]  as? String ?: ""
                    
                    Log.d(TAG, "Restoring notification for last word: id=$lastWordId ($title)")
                    NotificationHelper.scheduleRepeatingNotification(context, title, body, lastWordId)
                } else {
                    Log.d(TAG, "Last word id=$lastWordId not found in DB, skipping restoration")
                }
            } else {
                Log.d(TAG, "No last word id found to restore")
                // Необязательно: если база не пуста, можно запланировать "следующее" слово
                val words = db.getAllWords()
                if (words.isNotEmpty()) {
                    val nextWord = db.getNextWord(-1L)
                    if (nextWord != null) {
                        val title = nextWord["foreign_word"] as? String ?: ""
                        val body  = nextWord["translation"]  as? String ?: ""
                        Log.d(TAG, "Starting new cycle from first word")
                        NotificationHelper.scheduleRepeatingNotification(context, title, body, nextWord["id"] as Long)
                    }
                }
            }
        }
    }
}
