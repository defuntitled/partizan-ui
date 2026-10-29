package partizan.client

import java.math.BigInteger
import java.net.InetAddress

/** An IPv4 or IPv6 network; host bits are zero. */
data class Cidr(val bits: BigInteger, val prefix: Int, val v6: Boolean) {
    val width: Int get() = if (v6) 128 else 32

    val address: InetAddress
        get() {
            val raw = bits.toByteArray().takeLast(width / 8).toByteArray()
            val padded = ByteArray(width / 8 - raw.size) + raw
            return InetAddress.getByAddress(padded)
        }

    /** Whether [other] lies inside this network. */
    fun contains(other: Cidr): Boolean =
        v6 == other.v6 && prefix <= other.prefix &&
            other.bits.shiftRight(width - prefix) == bits.shiftRight(width - prefix)

    override fun toString(): String = "${address.hostAddress}/$prefix"

    companion object {
        /** `99.84.0.0/16`, `203.0.113.7`, `2606:4700::/32`. */
        fun parse(text: String): Cidr {
            val slash = text.indexOf('/')
            val host = if (slash < 0) text else text.substring(0, slash)
            require(host.isNotEmpty() && (host.contains(':') || host.count { it == '.' } == 3)) {
                "not an address: $text"
            }
            // Literals only: never a DNS lookup.
            val address = InetAddress.getByName(host)
            val v6 = address.address.size == 16
            val width = if (v6) 128 else 32
            val prefix = if (slash < 0) width else text.substring(slash + 1).toInt()
            require(prefix in 0..width) { "bad prefix: $text" }
            return of(BigInteger(1, address.address), prefix, v6)
        }

        fun of(bits: BigInteger, prefix: Int, v6: Boolean): Cidr {
            val width = if (v6) 128 else 32
            val masked = bits.shiftRight(width - prefix).shiftLeft(width - prefix)
            return Cidr(masked, prefix, v6)
        }

        val ALL_V4 = Cidr(BigInteger.ZERO, 0, false)
        val ALL_V6 = Cidr(BigInteger.ZERO, 0, true)
    }
}

/**
 * The routes of the TUN interface for split tunneling (spec: «Раздельное туннелирование»).
 * Include: only the listed networks. Exclude: everything but them, as `excludeRoute` where
 * the system has it (Android 13+), otherwise as the address space split around them. DNS
 * servers always get a route of their own: DNS never leaks, whatever the mode.
 */
data class RoutePlan(val add: List<Cidr>, val exclude: List<Cidr>) {
    companion object {
        fun of(include: Boolean, nets: List<Cidr>, dns: List<Cidr>, canExclude: Boolean): RoutePlan {
            val add =
                when {
                    include -> nets
                    canExclude -> listOf(Cidr.ALL_V4, Cidr.ALL_V6)
                    else -> complement(Cidr.ALL_V4, nets) + complement(Cidr.ALL_V6, nets)
                }
            val exclude = if (!include && canExclude) nets else emptyList()
            return RoutePlan((add + dns).distinct(), exclude)
        }

        /** [block] minus [excluded], as the fewest aligned networks. */
        fun complement(block: Cidr, excluded: List<Cidr>): List<Cidr> {
            val relevant = excluded.filter { it.v6 == block.v6 }
            val out = mutableListOf<Cidr>()
            fun walk(b: Cidr) {
                when {
                    relevant.any { it.contains(b) } -> {}
                    relevant.none { b.contains(it) } -> out += b
                    else -> {
                        val half = BigInteger.ONE.shiftLeft(b.width - b.prefix - 1)
                        walk(Cidr(b.bits, b.prefix + 1, b.v6))
                        walk(Cidr(b.bits.add(half), b.prefix + 1, b.v6))
                    }
                }
            }
            walk(block)
            return out
        }
    }
}
