package partizan.client

import org.junit.Assert.assertEquals
import org.junit.Test

class OnFailureTest {
    @Test
    fun aFailureWithTheKillSwitchOnKeepsTheInternetBlocked() {
        assertEquals(OnFailure.BLOCK, OnFailure.decide(killSwitch = true, userStopped = false))
    }

    @Test
    fun aFailureWithTheKillSwitchOffLetsTrafficGoDirect() {
        assertEquals(OnFailure.RELEASE, OnFailure.decide(killSwitch = false, userStopped = false))
    }

    @Test
    fun theUsersOwnDisconnectAlwaysReleases() {
        assertEquals(OnFailure.RELEASE, OnFailure.decide(killSwitch = true, userStopped = true))
        assertEquals(OnFailure.RELEASE, OnFailure.decide(killSwitch = false, userStopped = true))
    }
}
