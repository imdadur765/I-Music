package com.example.i_music

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import com.ryanheise.audioservice.AudioService

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "i_music/media_store"
    private val PERMISSION_REQUEST_CODE = 100
    private val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setTurnScreenOn(true)
            setShowWhenLocked(true)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllSongs" -> handleGetAllSongs(result)
                "checkPermissions" -> handleCheckPermissions(result)
                "requestPermissions" -> handleRequestPermissions(result)
                "minimizeApp" -> {
                    minimizeApp()
                    result.success("App minimized")
                }
                else -> result.notImplemented()
            }
        }
    }

    // ✅ MINIMIZE APP METHOD (SIRF FLUTTER SE CALL Hoga)
    private fun minimizeApp() {
        try {
            Log.d(TAG, "minimizeApp: Minimizing app to background")
            moveTaskToBack(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error minimizing app: $e")
        }
    }

    // ❌❌❌ YEH METHOD COMPLETELY COMMENT OUT/REMOVE KARO ❌❌❌
    /*
    override fun onBackPressed() {
        Log.d(TAG, "onBackPressed: Back button pressed - Using native handling")
        minimizeApp()
    }
    */

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Activity being destroyed")
        stopAudioService()
        super.onDestroy()
    }

    private fun stopAudioService() {
        try {
            Log.d(TAG, "stopAudioService: Stopping audio service")
            
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("stopAudioService", null)
            }

            Log.d(TAG, "✅ Audio service stop command sent via method channel")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping audio service: $e")
            e.printStackTrace()
        }
    }

    // 🎵 FETCH ALL SONGS
    private fun handleGetAllSongs(result: MethodChannel.Result) {
        if (!hasStoragePermission()) {
            result.error("PERMISSION_DENIED", "Storage permission required", null)
            return
        }

        try {
            val songs = getAllSongsFromMediaStore()
            result.success(songs)
        } catch (e: Exception) {
            result.error("FETCH_ERROR", e.message, null)
        }
    }

    // 📱 CHECK PERMISSIONS
    private fun handleCheckPermissions(result: MethodChannel.Result) {
        val permissions = mapOf(
            "hasStoragePermission" to hasStoragePermission(),
            "hasAudioPermission" to hasAudioPermission()
        )
        result.success(permissions)
    }

    // 🔐 REQUEST PERMISSIONS
    private fun handleRequestPermissions(result: MethodChannel.Result) {
        requestStoragePermission()
        result.success("Permissions requested")
    }

    // ✅ PERMISSION CHECK (Android 13+)
    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestStoragePermission() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.READ_MEDIA_AUDIO, Manifest.permission.POST_NOTIFICATIONS)
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }

        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
    }

    // 🎧 GET ALL SONGS FROM MEDIA STORE
    private fun getAllSongsFromMediaStore(): ArrayList<HashMap<String, Any>> {
        val songsList = ArrayList<HashMap<String, Any>>()

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.MIME_TYPE
        )

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} >= 10000"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        val cursor: Cursor? = contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            null,
            sortOrder
        )

        cursor?.use { c ->
            val idColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val albumIdColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val dateAddedColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val sizeColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val mimeTypeColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)

            while (c.moveToNext()) {
                val song = HashMap<String, Any>()

                val id = c.getLong(idColumn)
                val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                val albumArt = getAlbumArt(c.getLong(albumIdColumn))

                song["id"] = id.toString()
                song["title"] = c.getString(titleColumn) ?: "Unknown Title"
                song["artist"] = c.getString(artistColumn) ?: "Unknown Artist"
                song["album"] = c.getString(albumColumn) ?: "Unknown Album"
                song["duration"] = c.getLong(durationColumn)
                song["uri"] = contentUri.toString()
                song["albumArt"] = albumArt ?: ""
                song["dateAdded"] = c.getLong(dateAddedColumn)
                song["fileSize"] = c.getLong(sizeColumn)
                song["mimeType"] = c.getString(mimeTypeColumn) ?: "audio/mpeg"

                songsList.add(song)
            }
        }

        return songsList
    }

    private fun getAlbumArt(albumId: Long): String? {
        return try {
            if (albumId > 0) {
                val albumArtUri = ContentUris.withAppendedId(
                    android.net.Uri.parse("content://media/external/audio/albumart"),
                    albumId
                )
                albumArtUri.toString()
            } else null
        } catch (e: Exception) {
            null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val results = HashMap<String, Boolean>()
            permissions.forEachIndexed { index, permission ->
                results[permission] = grantResults[index] == PackageManager.PERMISSION_GRANTED
            }

            flutterEngine?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onPermissionsResult", results)
            }
        }
    }
}