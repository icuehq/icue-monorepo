package school.icue.icue_face_sdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify

class IcueFaceSdkPluginTest {
    @Test
    fun getInfoBeforeInitializationReturnsTypedError() {
        val plugin = IcueFaceSdkPlugin()
        val result = mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("getInfo", null), result)

        verify(result).error("NOT_INITIALIZED", "SDK is not initialized", null)
    }

    @Test
    fun unknownMethodIsNotImplemented() {
        val plugin = IcueFaceSdkPlugin()
        val result = mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("unknown", null), result)

        verify(result).notImplemented()
    }
}
