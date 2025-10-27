package com.example.i_music

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.ByteArrayOutputStream

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "i_music/media_store"
    private val PERMISSION_REQUEST_CODE = 100
    private val TAG = "MainActivity"

    // ✅ MEMORY CACHE FOR FASTER ACCESS
    private val thumbnailCache = mutableMapOf<Long, ByteArray>()

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
                "getAlbumArtBytes" -> {
                    val albumId = call.argument<Int>("albumId")?.toLong()
                    handleGetAlbumArtBytes(albumId, result)
                }
                "getSongThumbnail" -> {
                    val songId = call.argument<Int>("songId")?.toLong()
                    handleGetSongThumbnail(songId, result)
                }
                "preloadThumbnails" -> {
                    val albumIds = call.argument<List<Int>>("albumIds")?.map { it.toLong() }
                    handlePreloadThumbnails(albumIds, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ✅ NEW: PRELOAD THUMBNAILS FOR FASTER ACCESS
    private fun handlePreloadThumbnails(albumIds: List<Long>?, result: MethodChannel.Result) {
        if (!hasStoragePermission()) {
            result.error("PERMISSION_DENIED", "Storage permission required", null)
            return
        }

        try {
            if (albumIds.isNullOrEmpty()) {
                result.success(0)
                return
            }

            var loadedCount = 0
            for (albumId in albumIds) {
                if (albumId > 0 && !thumbnailCache.containsKey(albumId)) {
                    val thumbnail = getAlbumArtBytes(albumId)
                    if (thumbnail != null) {
                        loadedCount++
                    }
                }
            }
            
            result.success(loadedCount)
            Log.d(TAG, "✅ Preloaded $loadedCount thumbnails")
        } catch (e: Exception) {
            Log.e(TAG, "Error in preloadThumbnails: $e")
            result.error("PRELOAD_ERROR", e.message, null)
        }
    }

    // ✅ OPTIMIZED: FASTER ALBUM ART LOADING WITH CACHE
    private fun handleGetAlbumArtBytes(albumId: Long?, result: MethodChannel.Result) {
        if (!hasStoragePermission()) {
            result.error("PERMISSION_DENIED", "Storage permission required", null)
            return
        }

        try {
            if (albumId == null || albumId <= 0) {
                result.success(ByteArray(0))
                return
            }

            // ✅ CHECK MEMORY CACHE FIRST (INSTANT)
            if (thumbnailCache.containsKey(albumId)) {
                result.success(thumbnailCache[albumId])
                return
            }

            val albumArtBytes = getAlbumArtBytes(albumId)
            result.success(albumArtBytes ?: ByteArray(0))
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleGetAlbumArtBytes: $e")
            result.success(ByteArray(0)) // Return empty instead of error
        }
    }

    // ✅ OPTIMIZED: FASTER SONG THUMBNAIL WITH CACHE
    private fun handleGetSongThumbnail(songId: Long?, result: MethodChannel.Result) {
        if (!hasStoragePermission()) {
            result.error("PERMISSION_DENIED", "Storage permission required", null)
            return
        }

        try {
            if (songId == null || songId <= 0) {
                result.success(ByteArray(0))
                return
            }

            val thumbnailBytes = getSongThumbnail(songId)
            result.success(thumbnailBytes ?: ByteArray(0))
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleGetSongThumbnail: $e")
            result.success(ByteArray(0)) // Return empty instead of error
        }
    }

    // ✅ OPTIMIZED: GET ALBUM ART WITH CACHE AND FASTER PROCESSING
    private fun getAlbumArtBytes(albumId: Long): ByteArray? {
        return try {
            // ✅ CHECK CACHE FIRST
            if (thumbnailCache.containsKey(albumId)) {
                return thumbnailCache[albumId]
            }

            val albumArtUri = ContentUris.withAppendedId(
                android.net.Uri.parse("content://media/external/audio/albumart"),
                albumId
            )
            
            contentResolver.openInputStream(albumArtUri)?.use { inputStream ->
                val options = BitmapFactory.Options().apply {
                    inSampleSize = 2 // ✅ FASTER DECODING
                    inPreferredConfig = Bitmap.Config.RGB_565 // ✅ LESS MEMORY
                }
                
                val bitmap = BitmapFactory.decodeStream(inputStream, null, options)
                if (bitmap != null) {
                    val optimizedBitmap = optimizeBitmapSize(bitmap)
                    val stream = ByteArrayOutputStream()
                    
                    // ✅ OPTIMIZED COMPRESSION FOR FASTER PROCESSING
                    optimizedBitmap.compress(Bitmap.CompressFormat.JPEG, 150, stream) // Reduced quality for speed
                    val bytes = stream.toByteArray()
                    
                    // ✅ STORE IN MEMORY CACHE
                    thumbnailCache[albumId] = bytes
                    
                    bytes
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting album art bytes: $e")
            null
        }
    }

    // ✅ OPTIMIZED: GET SONG THUMBNAIL
    private fun getSongThumbnail(songId: Long): ByteArray? {
        return try {
            val projection = arrayOf(MediaStore.Audio.Media.ALBUM_ID)
            val selection = "${MediaStore.Audio.Media._ID} = ?"
            val selectionArgs = arrayOf(songId.toString())
            
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val albumId = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID))
                    getAlbumArtBytes(albumId)
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting song thumbnail: $e")
            null
        }
    }

    // ✅ OPTIMIZED: SMALLER BITMAP SIZE FOR FASTER LOADING
    private fun optimizeBitmapSize(bitmap: Bitmap): Bitmap {
        val maxWidth = 200  // ✅ REDUCED FROM 300 FOR FASTER PROCESSING
        val maxHeight = 200
        
        if (bitmap.width <= maxWidth && bitmap.height <= maxHeight) {
            return bitmap
        }
        
        val scale = Math.min(
            maxWidth.toFloat() / bitmap.width,
            maxHeight.toFloat() / bitmap.height
        )
        
        val newWidth = (bitmap.width * scale).toInt()
        val newHeight = (bitmap.height * scale).toInt()
        
        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }

    // ✅ MINIMIZE APP METHOD
    private fun minimizeApp() {
        try {
            Log.d(TAG, "minimizeApp: Minimizing app to background")
            moveTaskToBack(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error minimizing app: $e")
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Activity being destroyed")
        // ✅ CLEAR CACHE TO SAVE MEMORY
        thumbnailCache.clear()
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

            Log.d(TAG, "Audio service stop command sent via method channel")

        } catch (e: Exception) {
            Log.e(TAG, "Error stopping audio service: $e")
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
                song["albumId"] = c.getLong(albumIdColumn)

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