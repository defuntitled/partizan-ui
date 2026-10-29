package partizan.client

import java.math.BigInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RoutePlanTest {
    private fun nets(vararg s: String) = s.map(Cidr::parse)

    private val dns = nets("1.1.1.1", "2606:4700:4700::1111")

    /** Whether `address` is routed into the interface by `plan` (longest prefix wins). */
    private fun tunneled(plan: RoutePlan, address: String): Boolean {
        val a = Cidr.parse(address)
        val add = plan.add.filter { it.contains(a) }.maxOfOrNull { it.prefix } ?: -1
        val exclude = plan.exclude.filter { it.contains(a) }.maxOfOrNull { it.prefix } ?: -1
        return add > exclude
    }

    @Test
    fun networksParseAndNormalize() {
        assertEquals("99.84.0.0/16", Cidr.parse("99.84.1.2/16").toString())
        assertEquals("203.0.113.7/32", Cidr.parse("203.0.113.7").toString())
        assertEquals(32, Cidr.parse("2606:4700::/32").prefix)
        assertTrue(Cidr.parse("10.0.0.0/8").contains(Cidr.parse("10.1.2.3")))
        assertFalse(Cidr.parse("10.0.0.0/8").contains(Cidr.parse("::a00:1")))
    }

    @Test
    fun includeRoutesOnlyTheListedNetworksAndDns() {
        val plan = RoutePlan.of(true, nets("99.84.0.0/16", "2606:4700::/32"), dns, canExclude = true)
        assertEquals(nets("99.84.0.0/16", "2606:4700::/32") + dns, plan.add)
        assertTrue(plan.exclude.isEmpty())
        assertTrue(tunneled(plan, "99.84.10.1"))
        assertFalse(tunneled(plan, "8.8.8.8"))
        assertTrue(tunneled(plan, "1.1.1.1"))
    }

    @Test
    fun excludeOnAndroid13UsesExcludeRoute() {
        val plan = RoutePlan.of(false, nets("192.168.0.0/16"), dns, canExclude = true)
        assertTrue(Cidr.ALL_V4 in plan.add && Cidr.ALL_V6 in plan.add)
        assertEquals(nets("192.168.0.0/16"), plan.exclude)
        assertFalse(tunneled(plan, "192.168.1.10"))
        assertTrue(tunneled(plan, "8.8.8.8"))
        assertTrue(tunneled(plan, "2001:db8::1"))
    }

    @Test
    fun excludeOnOlderAndroidSplitsTheAddressSpace() {
        val excluded = nets("192.168.0.0/16", "10.0.0.0/8", "2001:db8::/32")
        val plan = RoutePlan.of(false, excluded, dns, canExclude = false)
        assertTrue(plan.exclude.isEmpty())
        for (a in listOf("192.168.1.10", "10.200.0.1", "2001:db8::5")) assertFalse(a, tunneled(plan, a))
        for (a in listOf("8.8.8.8", "192.169.0.1", "9.255.255.255", "11.0.0.0", "2001:db9::1", "::1")) {
            assertTrue(a, tunneled(plan, a))
        }
        // No overlap and nothing missing: the IPv4 blocks add up to 2^32 minus the excluded.
        val v4 = RoutePlan.complement(Cidr.ALL_V4, excluded)
        val size = v4.fold(BigInteger.ZERO) { acc, c -> acc + BigInteger.ONE.shiftLeft(32 - c.prefix) }
        assertEquals(BigInteger.ONE.shiftLeft(32) - BigInteger.ONE.shiftLeft(16) - BigInteger.ONE.shiftLeft(24), size)
        // And none of the blocks touches an excluded network.
        assertTrue(v4.none { block -> excluded.any { it.contains(block) || block.contains(it) } })
    }

    @Test
    fun dnsStaysInTheTunnelEvenWhenExcluded() {
        val excluded = nets("1.0.0.0/8")
        for (canExclude in listOf(true, false)) {
            val plan = RoutePlan.of(false, excluded, dns, canExclude)
            assertTrue(tunneled(plan, "1.1.1.1"))
            assertFalse(tunneled(plan, "1.2.3.4"))
        }
    }

    @Test
    fun nothingExcludedMeansEverything() {
        assertEquals(listOf(Cidr.ALL_V4), RoutePlan.complement(Cidr.ALL_V4, emptyList()))
        assertEquals(emptyList<Cidr>(), RoutePlan.complement(Cidr.ALL_V4, nets("0.0.0.0/0")))
    }
}
