package partizan.client

import org.junit.Assert.assertEquals
import org.junit.Test

class QuickActionTest {
    @Test
    fun aRunningTunnelIsAlwaysTakenDown() {
        for (profile in listOf(true, false)) {
            for (permitted in listOf(true, false)) {
                assertEquals(QuickAction.STOP, QuickAction.decide(true, profile, permitted))
            }
        }
    }

    @Test
    fun noProfileSendsToTheServerList() {
        assertEquals(QuickAction.OPEN_SERVERS, QuickAction.decide(false, false, true))
        assertEquals(QuickAction.OPEN_SERVERS, QuickAction.decide(false, false, false))
    }

    @Test
    fun noPermissionSendsToTheAppToAsk() {
        assertEquals(QuickAction.OPEN_FOR_PERMISSION, QuickAction.decide(false, true, false))
    }

    @Test
    fun otherwiseTheActiveProfileStarts() {
        assertEquals(QuickAction.START, QuickAction.decide(false, true, true))
    }
}
