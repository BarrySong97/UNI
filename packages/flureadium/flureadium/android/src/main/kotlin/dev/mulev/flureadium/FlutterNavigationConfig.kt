package dev.mulev.flureadium

data class FlutterNavigationConfig(
    val enableEdgeTapNavigation: Boolean? = null,
    val enableSwipeNavigation: Boolean? = null,
    val edgeTapAreaPoints: Double? = null,
) {
    companion object {
        private const val MIN_EDGE_TAP_DP = 44.0
        private const val MAX_EDGE_TAP_DP = 120.0

        fun fromMap(map: Map<*, *>?): FlutterNavigationConfig {
            if (map == null) return FlutterNavigationConfig()
            val rawPts = (map["edgeTapAreaPoints"] as? Number)?.toDouble()
            val clamped = rawPts?.coerceIn(MIN_EDGE_TAP_DP, MAX_EDGE_TAP_DP)
            return FlutterNavigationConfig(
                enableEdgeTapNavigation = map["enableEdgeTapNavigation"] as? Boolean,
                enableSwipeNavigation = map["enableSwipeNavigation"] as? Boolean,
                edgeTapAreaPoints = clamped,
            )
        }
    }
}
