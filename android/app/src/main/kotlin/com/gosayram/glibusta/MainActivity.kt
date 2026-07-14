package com.gosayram.glibusta

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.gosayram.glibusta/storage_bridge"
    private val DJVU_CHANNEL = "glibusta/djvu"
    private val maxImportFileBytes = 500L * 1024 * 1024
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPermResult: MethodChannel.Result? = null

    private val notifPermLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            pendingPermResult?.success(granted)
            pendingPermResult = null
        }

    private val openTreeLauncher: ActivityResultLauncher<Uri?> =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
            if (uri != null && pendingResult != null) {
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                try {
                    contentResolver.takePersistableUriPermission(uri, flags)
                    pendingResult!!.success(uri.toString())
                } catch (e: SecurityException) {
                    pendingResult!!.error("PERMISSION_ERROR", "Cannot persist URI permission: ${e.message}", null)
                }
                pendingResult = null
            } else {
                pendingResult?.success(null)
                pendingResult = null
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DJVU_CHANNEL)
            .setMethodCallHandler { call, result -> handleDjvuCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> {
                if (pendingResult != null) {
                    result.error("PICKER_IN_PROGRESS", "Folder picker is already open", null)
                    return
                }
                pendingResult = result
                openTreeLauncher.launch(null)
            }
            "scanBooks" -> {
                val folderUri = call.argument<String>("uri")
                if (folderUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                lifecycleScope.launch(Dispatchers.IO) {
                    try {
                        val books = scanBooks(Uri.parse(folderUri))
                        withContext(Dispatchers.Main) {
                            result.success(books)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SCAN_ERROR", e.message, null)
                        }
                    }
                }
            }
            "countBooks" -> {
                val folderUri = call.argument<String>("uri")
                if (folderUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                lifecycleScope.launch(Dispatchers.IO) {
                    try {
                        val count = countBooks(Uri.parse(folderUri))
                        withContext(Dispatchers.Main) {
                            result.success(count)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SCAN_ERROR", e.message, null)
                        }
                    }
                }
            }
            "copyToCache" -> {
                val fileUri = call.argument<String>("uri")
                if (fileUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                copyToCache(Uri.parse(fileUri), result)
            }
            "getPersistedUris" -> {
                val uris = contentResolver.persistedUriPermissions
                    .map { it.uri.toString() }
                result.success(uris)
            }
            "forgetUri" -> {
                val fileUri = call.argument<String>("uri")
                if (fileUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                try {
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    contentResolver.releasePersistableUriPermission(Uri.parse(fileUri), flags)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("FORGET_ERROR", e.message, null)
                }
            }
            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val perm = android.Manifest.permission.POST_NOTIFICATIONS
                    if (ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingPermResult = result
                        notifPermLauncher.launch(perm)
                    }
                } else {
                    result.success(true)
                }
            }
            "checkStoragePermission" -> {
                result.success(hasStoragePermission())
            }
            "requestStoragePermission" -> {
                if (hasStoragePermission()) {
                    result.success(true)
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                            intent.data = Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(false)
                    } else {
                        pendingPermResult = result
                        notifPermLauncher.launch(android.Manifest.permission.READ_EXTERNAL_STORAGE)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleDjvuCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                result.error("NOT_SUPPORTED", "DjVu format is not supported. Convert to EPUB or PDF first.", null)
            }
            "renderPage" -> {
                result.error("NOT_SUPPORTED", "DjVu format is not supported. Convert to EPUB or PDF first.", null)
            }
            "extractText" -> {
                result.error("NOT_SUPPORTED", "DjVu format is not supported. Convert to EPUB or PDF first.", null)
            }
            "close" -> {
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun scanBooks(treeUri: Uri): List<Map<String, Any>> {
        val root = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw IllegalStateException("Cannot access folder")

        val supportedExtensions = setOf("epub", "fb2", "zip", "txt", "rtf", "pdf", "mobi", "azw", "azw3", "prc", "djvu", "djv")
        val books = mutableListOf<Map<String, Any>>()

        collectBooks(root, supportedExtensions, books)

        return books
    }

    private fun countBooks(treeUri: Uri): Int {
        val root = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw IllegalStateException("Cannot access folder")
        val supportedExtensions = setOf("epub", "fb2", "zip", "txt", "rtf", "pdf", "mobi", "azw", "azw3", "prc", "djvu", "djv")
        val directories = ArrayDeque<DocumentFile>().apply { add(root) }
        var count = 0
        while (directories.isNotEmpty()) {
            for (file in directories.removeFirst().listFiles()) {
                if (file.isDirectory) {
                    directories.addLast(file)
                    continue
                }
                val name = file.name ?: continue
                val extension = name.substringAfterLast('.', "").lowercase()
                if (file.isFile && !isHiddenOrTemporary(name) && extension in supportedExtensions) {
                    count++
                }
            }
        }
        return count
    }

    private fun collectBooks(
        directory: DocumentFile,
        supportedExtensions: Set<String>,
        books: MutableList<Map<String, Any>>,
    ) {
        val directories = ArrayDeque<DocumentFile>().apply { add(directory) }
        while (directories.isNotEmpty()) {
            for (file in directories.removeFirst().listFiles()) {
                if (file.isDirectory) {
                    directories.addLast(file)
                    continue
                }
                if (!file.isFile) continue

                val name = file.name ?: continue
                if (isHiddenOrTemporary(name)) continue

                val ext = name.substringAfterLast('.', "").lowercase()
                if (ext !in supportedExtensions) continue

                books.add(mapOf(
                    "uri" to file.uri.toString(),
                    "name" to name,
                    "size" to file.length(),
                    "extension" to ext,
                    "mimeType" to (file.type ?: ""),
                    "lastModified" to file.lastModified(),
                ))
            }
        }
    }

    private fun isHiddenOrTemporary(name: String): Boolean {
        val lower = name.lowercase()
        return lower.startsWith(".") ||
            lower.endsWith(".tmp") ||
            lower.endsWith(".temp") ||
            lower.endsWith(".part") ||
            lower.endsWith(".crdownload") ||
            lower.endsWith("~")
    }

    private fun copyToCache(fileUri: Uri, result: MethodChannel.Result) {
        lifecycleScope.launch(Dispatchers.IO) {
            var tempFile: java.io.File? = null
            try {
                tempFile = java.io.File.createTempFile("saf_", cacheFileSuffix(fileUri), cacheDir)
                val input = contentResolver.openInputStream(fileUri)
                    ?: throw IllegalStateException("Cannot open file")
                input.use { ins ->
                    tempFile.outputStream().use { out ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var copiedBytes = 0L
                        while (true) {
                            val read = ins.read(buffer)
                            if (read < 0) break
                            copiedBytes += read
                            if (copiedBytes > maxImportFileBytes) {
                                throw IllegalArgumentException("File exceeds the 500 MiB import limit")
                            }
                            out.write(buffer, 0, read)
                        }
                    }
                }
                withContext(Dispatchers.Main) {
                    result.success(tempFile.absolutePath)
                }
            } catch (e: Exception) {
                tempFile?.delete()
                withContext(Dispatchers.Main) {
                    result.error("READ_ERROR", e.message, null)
                }
            }
        }
    }

    private fun cacheFileSuffix(fileUri: Uri): String {
        val displayName = contentResolver.query(
            fileUri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
        }
        val extension = displayName?.substringAfterLast('.', "").orEmpty()
        return extension.takeIf(String::isNotBlank)?.let { ".${it}" } ?: ".tmp"
    }

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }
}
