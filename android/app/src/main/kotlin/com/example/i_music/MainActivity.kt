package com.example.i_music

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
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
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "i_music/media_store"
    private val PERMISSION_REQUEST_CODE = 100
    private val TAG = "MainActivity"

    // ✅ FIXED: Simple cache with Long keys (songId as Long)
    private val albumArtCache = mutableMapOf<Long, ByteArray>()

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
                "getAlbumArt" -> {
                    // ✅ FIXED: Use Number type and convert to Long - YAHI CHANGE KIYA HAI
                    val songId = call.argument<Number>("songId")?.toLong()
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    handleGetAlbumArt(songId, title, artist, result)
                }
                "getPlaceholderArt" -> {
                    handleGetPlaceholderArt(result)
                }
                "clearAlbumArtCache" -> {
                    albumArtCache.clear()
                    result.success("Cache cleared")
                }
                else -> result.notImplemented()
            }
        }
    }

    // ✅ FIXED: Album Art Extraction with Long songId
    private fun handleGetAlbumArt(songId: Long?, title: String?, artist: String?, result: MethodChannel.Result) {
        Log.d(TAG, "🎨 handleGetAlbumArt called for songId: $songId, title: $title")
        
        if (!hasStoragePermission()) {
            result.error("PERMISSION_DENIED", "Storage permission required", null)
            return
        }

        if (songId == null) {
            result.error("INVALID_ARGUMENT", "Song ID is required", null)
            return
        }

        try {
            // Check cache first - using Long key
            if (albumArtCache.containsKey(songId)) {
                Log.d(TAG, "🎨 Using cached album art for songId: $songId")
                result.success(albumArtCache[songId])
                return
            }

            val albumArt = getAlbumArtBytes(songId, title, artist)
            if (albumArt != null) {
                // Cache the result
                albumArtCache[songId] = albumArt
                Log.d(TAG, "🎨 Album art extracted and cached for songId: $songId (${albumArt.size} bytes)")
                result.success(albumArt)
            } else {
                Log.d(TAG, "❌ No album art found for songId: $songId")
                result.success(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error extracting album art: $e")
            result.error("ALBUM_ART_ERROR", e.message, null)
        }
    }

    // ✅ FIXED: Simplified album art extraction
    private fun getAlbumArtBytes(songId: Long, title: String?, artist: String?): ByteArray? {
        return try {
            // Method 1: Try direct MediaStore album art URI (Most reliable)
            getAlbumArtFromMediaStore(songId)?.let { return it }
            
            // Method 2: Try extracting from audio file metadata
            getAlbumArtFromAudioFile(songId)?.let { return it }
            
            // Method 3: Try searching by album name (Least reliable)
            if (!title.isNullOrEmpty()) {
                getAlbumArtByAlbumSearch(title, artist)?.let { return it }
            }
            
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in getAlbumArtBytes: $e")
            null
        }
    }

    // ✅ FIXED: Method 1 - Direct MediaStore album art
    private fun getAlbumArtFromMediaStore(songId: Long): ByteArray? {
        return try {
            Log.d(TAG, "🔍 Method 1: Trying MediaStore album art for songId: $songId")
            
            // First get the album ID for this song
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
                    if (albumId > 0) {
                        Log.d(TAG, "📀 Found album ID: $albumId for song: $songId")
                        
                        // Now get album art using album ID
                        val albumArtUri = Uri.parse("content://media/external/audio/albumart")
                        val albumUri = ContentUris.withAppendedId(albumArtUri, albumId)
                        
                        contentResolver.openInputStream(albumUri)?.use { inputStream ->
                            val bitmap = BitmapFactory.decodeStream(inputStream)
                            if (bitmap != null) {
                                Log.d(TAG, "✅ Successfully extracted album art via MediaStore")
                                return convertBitmapToByteArray(bitmap, 85) // Good quality
                            }
                        }
                    }
                }
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in getAlbumArtFromMediaStore: $e")
            null
        }
    }

    // ✅ FIXED: Method 2 - Extract from audio file metadata
    private fun getAlbumArtFromAudioFile(songId: Long): ByteArray? {
        return try {
            Log.d(TAG, "🔍 Method 2: Trying audio file metadata for songId: $songId")
            
            val projection = arrayOf(MediaStore.Audio.Media.DATA)
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
                    val filePath = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA))
                    if (!filePath.isNullOrEmpty()) {
                        Log.d(TAG, "📁 Found file path: $filePath")
                        return extractAlbumArtFromFile(filePath)
                    }
                }
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in getAlbumArtFromAudioFile: $e")
            null
        }
    }

    // ✅ FIXED: Method 3 - Search by album name (fallback)
    private fun getAlbumArtByAlbumSearch(album: String, artist: String?): ByteArray? {
        return try {
            Log.d(TAG, "🔍 Method 3: Trying album search for: $album by $artist")
            
            val projection = arrayOf(MediaStore.Audio.Albums._ID, MediaStore.Audio.Albums.ALBUM_ART)
            val selection = if (!artist.isNullOrEmpty()) {
                "${MediaStore.Audio.Albums.ALBUM} = ? AND ${MediaStore.Audio.Albums.ARTIST} = ?"
            } else {
                "${MediaStore.Audio.Albums.ALBUM} = ?"
            }
            
            val selectionArgs = if (!artist.isNullOrEmpty()) {
                arrayOf(album, artist)
            } else {
                arrayOf(album)
            }

            contentResolver.query(
                MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    // Try album art path first
                    val albumArtPath = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Albums.ALBUM_ART))
                    if (!albumArtPath.isNullOrEmpty()) {
                        Log.d(TAG, "📁 Found album art path: $albumArtPath")
                        val bitmap = BitmapFactory.decodeFile(albumArtPath)
                        if (bitmap != null) {
                            return convertBitmapToByteArray(bitmap, 85)
                        }
                    }
                    
                    // Fallback to album ID
                    val albumId = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Albums._ID))
                    if (albumId > 0) {
                        Log.d(TAG, "📀 Trying album ID: $albumId")
                        return getAlbumArtFromMediaStoreByAlbumId(albumId)
                    }
                }
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in getAlbumArtByAlbumSearch: $e")
            null
        }
    }

    // ✅ ADDED: Direct album art by album ID
    private fun getAlbumArtFromMediaStoreByAlbumId(albumId: Long): ByteArray? {
        return try {
            val albumArtUri = Uri.parse("content://media/external/audio/albumart")
            val albumUri = ContentUris.withAppendedId(albumArtUri, albumId)
            
            contentResolver.openInputStream(albumUri)?.use { inputStream ->
                val bitmap = BitmapFactory.decodeStream(inputStream)
                return convertBitmapToByteArray(bitmap, 85)
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in getAlbumArtFromMediaStoreByAlbumId: $e")
            null
        }
    }

    // ✅ FIXED: Extract album art from file using MediaMetadataRetriever
    private fun extractAlbumArtFromFile(filePath: String): ByteArray? {
        var retriever: MediaMetadataRetriever? = null
        return try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(filePath)
            
            val embeddedPicture = retriever.embeddedPicture
            if (embeddedPicture != null) {
                Log.d(TAG, "🎵 Successfully extracted album art from file metadata")
                return embeddedPicture // Return as-is without recompression
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error extracting album art from file: $e")
            null
        } finally {
            retriever?.release()
        }
    }

    // ✅ FIXED: Better bitmap conversion with quality control
    private fun convertBitmapToByteArray(bitmap: Bitmap?, quality: Int = 85): ByteArray? {
        if (bitmap == null) return null
        
        return try {
            val stream = ByteArrayOutputStream()
            
            // Use JPEG format for better compression
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
            val byteArray = stream.toByteArray()
            stream.close()
            
            Log.d(TAG, "📊 Bitmap converted to ${byteArray.size} bytes (quality: $quality%)")
            byteArray
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error converting bitmap to byte array: $e")
            null
        }
    }

    // ✅ ADDED: Placeholder album art generation
    private fun handleGetPlaceholderArt(result: MethodChannel.Result) {
        try {
            // Create a simple placeholder bitmap
            val bitmap = Bitmap.createBitmap(300, 300, Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bitmap)
            
            // Background color
            canvas.drawColor(android.graphics.Color.parseColor("#1E1E1E"))
            
            // Draw music note icon (using text)
            val paint = android.graphics.Paint().apply {
                color = android.graphics.Color.WHITE
                textSize = 120f
                textAlign = android.graphics.Paint.Align.CENTER
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
            
            canvas.drawText("🎵", 150f, 180f, paint)
            
            val byteArray = convertBitmapToByteArray(bitmap, 80)
            result.success(byteArray)
            
            Log.d(TAG, "🎨 Generated placeholder album art")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error generating placeholder art: $e")
            result.success(null)
        }
    }

    // ✅ MINIMIZE APP METHOD
    private fun minimizeApp() {
        try {
            Log.d(TAG, "minimizeApp: Minimizing app to background")
            moveTaskToBack(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error minimizing app: $e")
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Activity being destroyed")
        // Clear album art cache
        albumArtCache.clear()
        super.onDestroy()
    }

    // 🎵 FETCH ALL SONGS (Keep your existing implementation)
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

    // 🎧 GET ALL SONGS FROM MEDIA STORE (Keep your existing implementation)
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
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.DATA
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
            val dataColumn = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)

            while (c.moveToNext()) {
                val song = HashMap<String, Any>()

                val id = c.getLong(idColumn)
                val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)

                song["id"] = id
                song["title"] = c.getString(titleColumn) ?: "Unknown Title"
                song["artist"] = c.getString(artistColumn) ?: "Unknown Artist"
                song["album"] = c.getString(albumColumn) ?: "Unknown Album"
                song["duration"] = c.getLong(durationColumn)
                song["uri"] = contentUri.toString()
                song["albumId"] = c.getLong(albumIdColumn)
                song["dateAdded"] = c.getLong(dateAddedColumn)
                song["fileSize"] = c.getLong(sizeColumn)
                song["mimeType"] = c.getString(mimeTypeColumn) ?: "audio/mpeg"
                song["filePath"] = c.getString(dataColumn) ?: ""

                songsList.add(song)
            }
        }

        Log.d(TAG, "✅ Fetched ${songsList.size} songs from MediaStore")
        return songsList
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

    // ✅ ADDED: Method to get cache info (for debugging)
    fun getAlbumArtCacheInfo(): Map<String, Any> {
        return mapOf(
            "cacheSize" to albumArtCache.size,
            "cachedSongIds" to albumArtCache.keys.toList()
        )
    }
}