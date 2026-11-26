package school.icue.face.core.recognition

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TrackedIdentityCacheTest {
    // Two clearly different "faces" as 4-pixel luminance patterns.
    private val faceA = TrackedIdentityCache.signatureOf(floatArrayOf(10f, 200f, 10f, 200f))
    private val faceABrighter = TrackedIdentityCache.signatureOf(floatArrayOf(40f, 230f, 40f, 230f))
    private val faceB = TrackedIdentityCache.signatureOf(floatArrayOf(200f, 10f, 10f, 200f))

    private val matched = TrackedIdentityCache.Identity("student-1", 0.9f, matched = true, embedding = null, signature = faceA)
    private val unmatched = TrackedIdentityCache.Identity(null, 0.2f, matched = false, embedding = null, signature = faceA)

    @Test
    fun matchedFaceIsReusedUntilItsRefreshFrame() {
        val cache = TrackedIdentityCache(matchedRefreshFrames = 3, unmatchedRefreshFrames = 1)
        cache.startFrame(setOf(7))
        cache.store(7, matched)

        repeat(2) {
            cache.startFrame(setOf(7))
            assertEquals(matched, cache.reusable(7, faceA))
        }
        cache.startFrame(setOf(7))
        assertNull(cache.reusable(7, faceA))
    }

    @Test
    fun unmatchedFaceIsRecheckedSooner() {
        val cache = TrackedIdentityCache(matchedRefreshFrames = 10, unmatchedRefreshFrames = 2)
        cache.startFrame(setOf(3))
        cache.store(3, unmatched)

        cache.startFrame(setOf(3))
        assertEquals(unmatched, cache.reusable(3, faceA))
        cache.startFrame(setOf(3))
        assertNull(cache.reusable(3, faceA))
    }

    @Test
    fun swappedFaceUnderTheSameTrackingIdIsRecheckedAtOnce() {
        val cache = TrackedIdentityCache()
        cache.startFrame(setOf(5))
        cache.store(5, matched)

        cache.startFrame(setOf(5))
        assertNull(cache.reusable(5, faceB))
    }

    @Test
    fun sameFaceUnderBrighterLightIsStillReused() {
        val cache = TrackedIdentityCache()
        cache.startFrame(setOf(5))
        cache.store(5, matched)

        cache.startFrame(setOf(5))
        assertEquals(matched, cache.reusable(5, faceABrighter))
    }

    @Test
    fun faceThatCannotBeComparedIsRechecked() {
        val cache = TrackedIdentityCache()
        cache.startFrame(setOf(5))
        cache.store(5, matched)

        cache.startFrame(setOf(5))
        assertNull(cache.reusable(5, null))
    }

    @Test
    fun faceThatLeavesTrackingIsForgotten() {
        val cache = TrackedIdentityCache()
        cache.startFrame(setOf(1))
        cache.store(1, matched)

        cache.startFrame(emptySet())
        cache.startFrame(setOf(1))
        assertNull(cache.reusable(1, faceA))
    }

    @Test
    fun forgottenFaceIsRecheckedOnTheNextFrame() {
        val cache = TrackedIdentityCache()
        cache.startFrame(setOf(5))
        cache.store(5, matched)
        cache.forget(5)

        cache.startFrame(setOf(5))
        assertNull(cache.reusable(5, faceA))
    }

    @Test
    fun faceWithoutTrackingIdIsNeverCached() {
        val cache = TrackedIdentityCache()
        cache.startFrame(emptySet())
        cache.store(null, matched)

        assertNull(cache.reusable(null, faceA))
    }
}
