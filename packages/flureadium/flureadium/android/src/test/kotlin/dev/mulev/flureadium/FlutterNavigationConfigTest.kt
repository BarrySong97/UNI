package dev.mulev.flureadium

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertFalse

internal class FlutterNavigationConfigTest {

    @Test
    fun fromMap_parsesAllFields() {
        val map = mapOf(
            "enableEdgeTapNavigation" to true,
            "enableSwipeNavigation" to false,
            "edgeTapAreaPoints" to 80.0,
        )
        val config = FlutterNavigationConfig.fromMap(map)

        assertTrue(config.enableEdgeTapNavigation!!)
        assertFalse(config.enableSwipeNavigation!!)
        assertEquals(80.0, config.edgeTapAreaPoints)
    }

    @Test
    fun fromMap_handlesEmptyMap() {
        val config = FlutterNavigationConfig.fromMap(emptyMap<String, Any>())

        assertNull(config.enableEdgeTapNavigation)
        assertNull(config.enableSwipeNavigation)
        assertNull(config.edgeTapAreaPoints)
    }

    @Test
    fun fromMap_handlesNullMap() {
        val config = FlutterNavigationConfig.fromMap(null)

        assertNull(config.enableEdgeTapNavigation)
        assertNull(config.enableSwipeNavigation)
        assertNull(config.edgeTapAreaPoints)
    }

    @Test
    fun fromMap_clampsEdgeTapAreaPoints_belowMin() {
        val map = mapOf("edgeTapAreaPoints" to 10.0)
        val config = FlutterNavigationConfig.fromMap(map)

        assertEquals(44.0, config.edgeTapAreaPoints)
    }

    @Test
    fun fromMap_clampsEdgeTapAreaPoints_aboveMax() {
        val map = mapOf("edgeTapAreaPoints" to 200.0)
        val config = FlutterNavigationConfig.fromMap(map)

        assertEquals(120.0, config.edgeTapAreaPoints)
    }

    @Test
    fun fromMap_clampsEdgeTapAreaPoints_withinRange() {
        val map = mapOf("edgeTapAreaPoints" to 60.0)
        val config = FlutterNavigationConfig.fromMap(map)

        assertEquals(60.0, config.edgeTapAreaPoints)
    }

    @Test
    fun fromMap_defaultsToEnabledWhenNotSet() {
        // Null fields mean enabled per iOS semantics — the overlay checks != false
        val config = FlutterNavigationConfig.fromMap(emptyMap<String, Any>())

        // null != false → enabled
        assertTrue(config.enableEdgeTapNavigation != false)
        assertTrue(config.enableSwipeNavigation != false)
    }
}
