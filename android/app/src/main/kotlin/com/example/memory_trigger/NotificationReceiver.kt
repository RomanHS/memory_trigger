package com.example.memory_trigger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val foreignWord = intent.getStringExtra("title") ?: return
        val translation = intent.getStringExtra("body")  ?: ""
        val wordId      = intent.getLongExtra("wordId", -1L)

        NotificationHelper.showWordNotification(
            context     = context,
            wordId      = wordId,
            foreignWord = foreignWord,
            translation = translation
        )
    }
}
