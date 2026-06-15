package com.gosayram.glibusta

import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.gosayram.glibusta/storage_bridge"
    private val DJVU_CHANNEL = "glibusta/djvu"
    private var pendingResult: MethodChannel.Result? = null

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
                pendingResult = result
                openTreeLauncher.launch(null)
            }
            "scanBooks" -> {
                val folderUri = call.argument<String>("uri")
                if (folderUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                scanBooks(Uri.parse(folderUri), result)
            }
            "readFile" -> {
                val fileUri = call.argument<String>("uri")
                if (fileUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                readFile(Uri.parse(fileUri), result)
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
            else -> result.notImplemented()
        }
    }

    private fun handleDjvuCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                result.success(mapOf("pageCount" to 0))
            }
            "renderPage" -> {
                result.error("NOT_IMPLEMENTED", "DjVu renderer is not bundled yet", null)
            }
            "extractText" -> {
                result.success(null)
            }
            "close" -> {
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun scanBooks(treeUri: Uri, result: MethodChannel.Result) {
        try {
            val root = DocumentFile.fromTreeUri(this, treeUri)
            if (root == null) {
                result.error("SCAN_ERROR", "Cannot access folder", null)
                return
            }

            val supportedExtensions = setOf("epub", "fb2", "zip", "txt", "rtf", "pdf", "mobi", "azw", "azw3", "prc", "djvu", "djv")
            val books = mutableListOf<Map<String, Any>>()

            collectBooks(root, supportedExtensions, books)

            result.success(books)
        } catch (e: Exception) {
            result.error("SCAN_ERROR", e.message, null)
        }
    }

    private fun collectBooks(
        directory: DocumentFile,
        supportedExtensions: Set<String>,
        books: MutableList<Map<String, Any>>,
    ) {
        for (file in directory.listFiles()) {
            if (file.isDirectory) {
                collectBooks(file, supportedExtensions, books)
                continue
            }
            if (!file.isFile) continue

            val name = file.name ?: continue
            if (isHiddenOrTemporary(name)) continue

            val size = file.length()
            if (size <= 0L) continue

            val ext = name.substringAfterLast('.', "").lowercase()
            if (ext !in supportedExtensions) continue

            books.add(mapOf(
                "uri" to file.uri.toString(),
                "name" to name,
                "size" to size,
                "extension" to ext,
                "mimeType" to (file.type ?: ""),
                "lastModified" to file.lastModified(),
            ))
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
        try {
            val input = contentResolver.openInputStream(fileUri)
                ?: run {
                    result.error("READ_ERROR", "Cannot open file", null)
                    return
                }
            val cacheDir = cacheDir
            val tempFile = java.io.File(cacheDir, "saf_${System.currentTimeMillis()}.tmp")
            input.use { ins ->
                tempFile.outputStream().use { out ->
                    ins.copyTo(out, bufferSize = 8192)
                }
            }
            result.success(tempFile.absolutePath)
        } catch (e: Exception) {
            result.error("READ_ERROR", e.message, null)
        }
    }

    private fun readFile(fileUri: Uri, result: MethodChannel.Result) {
        try {
            contentResolver.openInputStream(fileUri)?.use { input ->
                val bytes = input.readBytes()
                result.success(bytes)
            } ?: result.error("READ_ERROR", "Cannot open file", null)
        } catch (e: Exception) {
            result.error("READ_ERROR", e.message, null)
        }
    }
}
