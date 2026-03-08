package dev.mulev.flureadium

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class EdgeTapInterceptViewTest {

    // ── Zone detection ────────────────────────────────────────────────────────

    @Test
    fun isInLeftEdgeZone_returnsTrue_whenXWithinThreshold() {
        assertTrue(EdgeTapInterceptView.isInLeftEdge(x = 30f, thresholdPx = 44f))
    }

    @Test
    fun isInLeftEdgeZone_returnsFalse_whenXOutsideThreshold() {
        assertFalse(EdgeTapInterceptView.isInLeftEdge(x = 100f, thresholdPx = 44f))
    }

    @Test
    fun isInRightEdgeZone_returnsTrue_whenXWithinThreshold() {
        // viewWidth = 400, threshold = 44 → right edge starts at 356
        assertTrue(EdgeTapInterceptView.isInRightEdge(x = 380f, viewWidth = 400, thresholdPx = 44f))
    }

    @Test
    fun isInRightEdgeZone_returnsFalse_whenXOutsideThreshold() {
        assertFalse(EdgeTapInterceptView.isInRightEdge(x = 200f, viewWidth = 400, thresholdPx = 44f))
    }

    // ── Density conversion ────────────────────────────────────────────────────

    @Test
    fun dpToPixels_convertsCorrectly() {
        // 44dp at density 2.0 → 88px
        assertEquals(88f, EdgeTapInterceptView.dpToPx(dp = 44f, density = 2.0f))
    }

    // ── Config application ────────────────────────────────────────────────────

    @Test
    fun applyConfig_disablesEdgeTap_whenFlagFalse() {
        val config = FlutterNavigationConfig(enableEdgeTapNavigation = false)
        assertFalse(EdgeTapInterceptView.effectiveEdgeTapEnabled(config, isScrollMode = false))
    }

    @Test
    fun applyConfig_keepsEdgeTap_whenFlagTrue() {
        val config = FlutterNavigationConfig(enableEdgeTapNavigation = true)
        assertTrue(EdgeTapInterceptView.effectiveEdgeTapEnabled(config, isScrollMode = false))
    }

    @Test
    fun applyConfig_keepsEdgeTap_whenFlagNull() {
        val config = FlutterNavigationConfig(enableEdgeTapNavigation = null)
        assertTrue(EdgeTapInterceptView.effectiveEdgeTapEnabled(config, isScrollMode = false))
    }

    @Test
    fun applyConfig_disablesSwipe_whenFlagFalse() {
        val config = FlutterNavigationConfig(enableSwipeNavigation = false)
        assertFalse(EdgeTapInterceptView.effectiveSwipeEnabled(config, isScrollMode = false))
    }

    @Test
    fun applyConfig_keepsSwipe_whenFlagTrue() {
        val config = FlutterNavigationConfig(enableSwipeNavigation = true)
        assertTrue(EdgeTapInterceptView.effectiveSwipeEnabled(config, isScrollMode = false))
    }

    @Test
    fun applyConfig_updatesEdgeZoneSize() {
        val config = FlutterNavigationConfig(edgeTapAreaPoints = 80.0)
        assertEquals(80f, EdgeTapInterceptView.effectiveThresholdDp(config))
    }

    @Test
    fun applyConfig_usesDefaultThreshold_whenEdgeTapAreaPointsNull() {
        val config = FlutterNavigationConfig(edgeTapAreaPoints = null)
        assertEquals(44f, EdgeTapInterceptView.effectiveThresholdDp(config))
    }

    // ── Scroll mode ───────────────────────────────────────────────────────────

    @Test
    fun setScrollMode_disablesAllGestures_whenTrue() {
        val config = FlutterNavigationConfig(
            enableEdgeTapNavigation = true,
            enableSwipeNavigation = true,
        )
        assertFalse(EdgeTapInterceptView.effectiveEdgeTapEnabled(config, isScrollMode = true))
        assertFalse(EdgeTapInterceptView.effectiveSwipeEnabled(config, isScrollMode = true))
    }

    @Test
    fun setScrollMode_restoresGestures_whenFalse() {
        val config = FlutterNavigationConfig(
            enableEdgeTapNavigation = true,
            enableSwipeNavigation = true,
        )
        assertTrue(EdgeTapInterceptView.effectiveEdgeTapEnabled(config, isScrollMode = false))
        assertTrue(EdgeTapInterceptView.effectiveSwipeEnabled(config, isScrollMode = false))
    }
}
