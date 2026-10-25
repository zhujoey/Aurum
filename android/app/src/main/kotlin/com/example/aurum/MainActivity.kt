package com.example.aurum

import android.content.Context
import android.os.Bundle
import androidx.appcompat.app.AppCompatDelegate
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.aurum/theme"

    override fun onCreate(savedInstanceState: Bundle?) {
        applyAppThemeMode()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setNativeNightMode") {
                val mode = call.argument<String>("mode") ?: "system"
                setNightMode(mode)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun applyAppThemeMode() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val themeMode = prefs.getString("flutter.themeMode", "dark") ?: "dark"
            setNightMode(themeMode)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setNightMode(mode: String) {
        when (mode) {
            "dark" -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
            "light" -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
            else -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        }
    }
}
