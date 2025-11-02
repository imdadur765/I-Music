package com.example.i_music

import android.content.Context
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class FileProviderHelper {
    companion object {
        fun setupMethodChannel(flutterEngine: FlutterEngine, context: Context) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "i_music/file_provider").setMethodCallHandler { call, result ->
                when (call.method) {
                    "getContentUri" -> {
                        try {
                            val filePath = call.argument<String>("filePath")
                            val authority = call.argument<String>("authority")
                            
                            if (filePath != null && authority != null) {
                                val file = File(filePath)
                                val contentUri = FileProvider.getUriForFile(context, authority, file)
                                result.success(mapOf("contentUri" to contentUri.toString()))
                            } else {
                                result.error("INVALID_ARGUMENTS", "File path or authority is null", null)
                            }
                        } catch (e: Exception) {
                            result.error("FILE_PROVIDER_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}