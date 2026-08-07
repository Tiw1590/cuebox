package com.cuebox.app

import android.app.Activity
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteOrder
import kotlin.math.sqrt

/**
 * SAF（Storage Access Framework）目录选择与浏览通道。
 *
 * 通过 ACTION_OPEN_DOCUMENT_TREE 让用户选择素材根目录，持久化读取权限，
 * 之后用 DocumentsContract 递归列出子文件夹与文件，返回 content:// URI。
 * 播放引擎（just_audio/ExoPlayer）可直接播放 content:// URI，无需存储权限。
 */
class SafChannel(private val activity: Activity) {

    private var pendingResult: MethodChannel.Result? = null

    fun registerWith(channel: MethodChannel) {
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "pickDirectory" -> pickDirectory(result)
                "listChildren" -> listChildren(call.argument<String>("uri"), result)
                "getTreeName" -> getTreeName(call.argument<String>("uri"), result)
                "extractWaveform" -> extractWaveform(
                    call.argument<String>("uri"),
                    call.argument<Int>("peakCount"),
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 用 MediaExtractor + MediaCodec 解码音频并提取 [peakCount] 个峰值（0..1），
     * 供 Cue 编辑页绘制波形。解码失败时返回 null，Dart 侧回退为占位波形。
     */
    private fun extractWaveform(uriString: String?, peakCount: Int?, result: MethodChannel.Result) {
        if (uriString == null || peakCount == null || peakCount <= 0) {
            result.error("bad_args", "Missing uri or peakCount", null)
            return
        }
        val uri = Uri.parse(uriString)
        val count = peakCount.coerceIn(32, 4096)
        Thread {
            try {
                val extractor = MediaExtractor()
                extractor.setDataSource(activity, uri, null)
                var trackIndex = -1
                var mime: String? = null
                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val m = format.getString(MediaFormat.KEY_MIME)
                    if (m != null && m.startsWith("audio/")) {
                        trackIndex = i
                        mime = m
                        break
                    }
                }
                if (trackIndex < 0) {
                    extractor.release()
                    result.success(null)
                    return@Thread
                }
                extractor.selectTrack(trackIndex)
                val format = extractor.getTrackFormat(trackIndex)
                val sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                    format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                } else 44100
                val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                    format.getLong(MediaFormat.KEY_DURATION)
                } else 0L
                val totalSamples = if (durationUs > 0) durationUs * sampleRate / 1_000_000 else 0L

                val codec = MediaCodec.createDecoderByType(mime!!)
                codec.configure(format, null, null, 0)
                codec.start()

                val sums = DoubleArray(count)
                val counts = LongArray(count)
                val bufferInfo = MediaCodec.BufferInfo()
                var sampleIndex = 0L
                var inputDone = false
                var outputDone = false
                var lastPeak = 0.0
                var idleTries = 0

                while (!outputDone) {
                    if (!inputDone) {
                        val inIndex = codec.dequeueInputBuffer(10_000)
                        if (inIndex >= 0) {
                            val inBuf = codec.getInputBuffer(inIndex)
                            val sampleSize = if (inBuf != null) extractor.readSampleData(inBuf, 0) else -1
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(inIndex, 0, sampleSize, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }

                    val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                    when {
                        outIndex >= 0 -> {
                            idleTries = 0
                            if (bufferInfo.size > 0 &&
                                (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                            ) {
                                val outBuf = codec.getOutputBuffer(outIndex)
                                if (outBuf != null) {
                                    outBuf.position(bufferInfo.offset)
                                    outBuf.limit(bufferInfo.offset + bufferInfo.size)
                                    outBuf.order(ByteOrder.LITTLE_ENDIAN)
                                    var sampleCount = bufferInfo.size / 2
                                    while (sampleCount-- > 0) {
                                        val s = outBuf.short.toInt()
                                        val norm = s.toDouble() / 32768.0
                                        val bucket = if (totalSamples > 0) {
                                            ((sampleIndex * count) / totalSamples).toInt()
                                                .coerceIn(0, count - 1)
                                        } else {
                                            (sampleIndex % count).toInt()
                                        }
                                        sums[bucket] += norm * norm
                                        counts[bucket]++
                                        sampleIndex++
                                    }
                                }
                            }
                            codec.releaseOutputBuffer(outIndex, false)
                            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                outputDone = true
                            }
                        }
                        outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            if (inputDone) {
                                if (++idleTries > 300) outputDone = true
                            }
                        }
                    }
                }
                codec.stop()
                codec.release()
                extractor.release()

                val rms = DoubleArray(count)
                for (i in 0 until count) {
                    if (counts[i] > 0) {
                        rms[i] = sqrt(sums[i] / counts[i])
                        lastPeak = rms[i]
                    } else {
                        rms[i] = lastPeak
                    }
                }
                // 轻平滑，让波形更接近真实听感、不刺眼。
                val smooth = DoubleArray(count)
                for (i in 0 until count) {
                    val a = if (i > 0) rms[i - 1] else rms[i]
                    val b = rms[i]
                    val c = if (i < count - 1) rms[i + 1] else rms[i]
                    smooth[i] = (a + 2 * b + c) / 4
                }
                result.success(smooth.toList())
            } catch (e: Exception) {
                try {
                    result.success(null)
                } catch (_: Exception) {
                    // 结果已发送或通道已关闭，忽略。
                }
            }
        }.start()
    }

    /** 返回 true 表示已处理（消费）了该 Activity 结果。 */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_TREE) return false
        val result = pendingResult
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return true
        }
        val uri: Uri = data.data!!
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: Exception) {
            // 持久化权限失败时，本次会话内仍可浏览；下次启动需重新选择目录。
        }
        result?.success(uri.toString())
        return true
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "A directory picker is already open", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        activity.startActivityForResult(intent, REQUEST_PICK_TREE)
    }

    private fun listChildren(uriString: String?, result: MethodChannel.Result) {
        if (uriString == null) {
            result.error("bad_uri", "Missing tree/document URI", null)
            return
        }
        val uri = Uri.parse(uriString)
        val entries = mutableListOf<Map<String, Any?>>()
        try {
            val docId = DocumentsContract.getTreeDocumentId(uri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(uri, docId)
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
            )
            activity.contentResolver.query(
                childrenUri, projection, null, null, null,
            )?.use { cursor ->
                val idCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                val sizeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                while (cursor.moveToNext()) {
                    val mime = cursor.getString(mimeCol) ?: ""
                    entries.add(
                        mapOf(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(uri, cursor.getString(idCol)).toString(),
                            "name" to (cursor.getString(nameCol) ?: ""),
                            "mime" to mime,
                            "isDirectory" to (mime == DocumentsContract.Document.MIME_TYPE_DIR),
                            "size" to cursor.getLong(sizeCol),
                        ),
                    )
                }
            }
            result.success(entries)
        } catch (e: Exception) {
            result.error("list_failed", e.message ?: "Failed to list directory", null)
        }
    }

    private fun getTreeName(uriString: String?, result: MethodChannel.Result) {
        if (uriString == null) {
            result.error("bad_uri", "Missing tree URI", null)
            return
        }
        val uri = Uri.parse(uriString)
        try {
            val docId = DocumentsContract.getTreeDocumentId(uri)
            val docUri = DocumentsContract.buildDocumentUriUsingTree(uri, docId)
            val projection = arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            var name: String? = null
            activity.contentResolver.query(docUri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val col = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    if (col >= 0) name = cursor.getString(col)
                }
            }
            result.success(name)
        } catch (e: Exception) {
            result.error("query_failed", e.message ?: "Failed to read tree name", null)
        }
    }

    companion object {
        private const val REQUEST_PICK_TREE = 7001
    }
}
