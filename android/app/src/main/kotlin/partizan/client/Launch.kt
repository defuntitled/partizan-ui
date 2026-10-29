package partizan.client

import android.content.Context

/**
 * What the tile and the widget need to bring the tunnel up without the app: the active
 * profile and its split tunneling rules. Dart keeps it current over `partizan/vpn`
 * (`setLaunch`). No secret here: the link is in the [SecretVault] under the profile id.
 */
data class Launch(
    val profileId: Int,
    val name: String,
    val include: Boolean,
    val routes: List<String>,
) {
    companion object {
        private const val PREFS = "partizan_launch"

        fun read(context: Context): Launch? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val id = prefs.getInt("profile", -1)
            if (id < 0) return null
            return Launch(
                id,
                prefs.getString("name", null) ?: "",
                prefs.getBoolean("include", false),
                prefs.getString("routes", "")!!.split(',').map(String::trim).filter(String::isNotEmpty),
            )
        }

        private const val KILL_SWITCH = "kill_switch"

        /** Kill Switch, set in the app's settings; it holds with or without a profile. */
        fun killSwitch(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KILL_SWITCH, false)

        /** `null` forgets it: no active profile. */
        fun write(context: Context, launch: Launch?, killSwitch: Boolean) {
            val edit =
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear()
                    .putBoolean(KILL_SWITCH, killSwitch)
            if (launch != null) {
                edit.putInt("profile", launch.profileId)
                    .putString("name", launch.name)
                    .putBoolean("include", launch.include)
                    .putString("routes", launch.routes.joinToString(","))
            }
            edit.commit()
        }
    }
}

/** What the service does when the tunnel fails on its own (spec: Kill Switch). */
enum class OnFailure {
    /** Keep the internet blocked behind an interface that carries nothing. */
    BLOCK,

    /** Take everything down: traffic goes direct again. */
    RELEASE;

    companion object {
        /** The user's own "disconnect" always releases; otherwise the Kill Switch decides. */
        fun decide(killSwitch: Boolean, userStopped: Boolean): OnFailure =
            if (killSwitch && !userStopped) BLOCK else RELEASE
    }
}

/** What a tap on the tile or the widget does. */
enum class QuickAction {
    /** Take the tunnel down. */
    STOP,

    /** Bring it up with the active profile. */
    START,

    /** No profile to start: the app, on the server list. */
    OPEN_SERVERS,

    /** The system has not granted the VPN yet: the app, which asks. */
    OPEN_FOR_PERMISSION;

    companion object {
        fun decide(tunnelUp: Boolean, hasProfile: Boolean, permitted: Boolean): QuickAction =
            when {
                tunnelUp -> STOP
                !hasProfile -> OPEN_SERVERS
                !permitted -> OPEN_FOR_PERMISSION
                else -> START
            }
    }
}
