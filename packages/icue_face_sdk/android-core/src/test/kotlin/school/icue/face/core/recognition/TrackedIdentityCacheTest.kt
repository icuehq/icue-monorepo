package school.icue.face.core.recognition

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TrackedIdentityCacheTest {
    private val matched = TrackedIdentityCache.Identity("student-1", 0.9f, matched = true)
    private val unmatched = TrackedIdentityCache.Identity(null, 0.2f, matched = false)

    @Test
    fun matchedFaceIsReusedUntilItsRefreshFrame() {
        val cache = TrackedIdentityCache(matchedRefreshFrames = 3, unmatchedRefreshFrames = 1)
        cache.startFrame(setOf(7))
        cache.store(7, matched)

        repeat(2) {
            cache.startFrame(setOf(7))
            assertEquals(matched, cache.reusable(7))
        }
        cache.startFrame(setOf(7))
        assertNull(cache.reusable(7))
    }

    @Test
    fun unmatchedFaceIsRecheckedSooner() {
        val cache = TrackedIdentityCache(matchedRefreshFrames = 10, unmatchedRefreshFrames = 2)
        cache.startFrame(setOf(3))
        cache.store(3, unmatched)

        cache.startFrame(setOf(3))
        assertEquals(unmatched, cache.reusable(3))
        cache.startFrame(setOf(3))
        assertNull(cache.reusable(3))
    }

    @Test
    fun faceThatLeavesTrackingIsForgotten() {
        val cache = TrackedIdentityCache()
        cache.startFrame(setOf(1))
        cache.store(1, matched)

        cache.startFrame(emptySet())
        cache.startFrame(setOf(1))
        assertNull(cache.reusable(1))
    }

    @Test
    fun faceWithoutTrackingIdIsNeverCached() {
        val cache = TrackedIdentityCache()
        cache.startFrame(emptySet())
        cache.store(null, matched)

        assertNull(cache.reusable(null))
    }
}
