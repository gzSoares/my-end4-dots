pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    property bool available: false
    property bool ready: false
    property string sourcePath: ""
    property string lastError: ""

    Connections {
        target: KdeConnectService
        ignoreUnknownSignals: true
        function onActiveDeviceIdChanged() {
            root.refresh()
        }
    }

    property var contacts: []
    property string searchQuery: ""
    property var filteredContacts: []

    readonly property int count: contacts ? contacts.length : 0
    // Contacts dropped by the nameless filter, so the UI can say why the list is short
    property int hiddenCount: 0

    readonly property bool hideUnnamed: Config.options?.phone?.contacts?.hideUnnamed ?? true
    onHideUnnamedChanged: root._updateFilteredContacts()

    function refresh(): void {
        // Mirrors the old daemon-restart semantics: a restart reset its dedup hash, so an explicit
        // refresh always re-published the list, and a refresh while no contact source existed did
        // nothing at all.
        if (!root._watching) return
        root._forceEmit = true
        root._readOnce()
    }

    function setSearchQuery(query: string): void {
        root.searchQuery = query
        root._updateFilteredContacts()
    }

    function contactById(id: string): var {
        if (!contacts) return null
        for (let i = 0; i < contacts.length; i++) {
            if (contacts[i].id === id) return contacts[i]
        }
        return null
    }

    /**
     * The contact a phone number belongs to, or null.
     *
     * Matched on the last nine digits, which is what survives every way a number gets
     * written: "+33 6 12 34 56 78", "0612345678" and "0033612345678" all end the same.
     */
    function contactByNumber(number: string): var {
        const digits = String(number ?? "").replace(/\D/g, "");
        if (digits.length < 6)
            return null;
        const tail = digits.slice(-9);
        for (const contact of (root.contacts ?? [])) {
            for (const phone of (contact.phones ?? [])) {
                const other = String(phone.value ?? phone ?? "").replace(/\D/g, "");
                if (other.length >= 6 && other.slice(-9) === tail)
                    return contact;
            }
        }
        return null;
    }

    function copyPhone(number: string): void {
        if (!number) return
        Quickshell.clipboardText = number
        KdeConnectService.dispatchActionFeedback(Translation.tr("Phone number copied"), true)
    }

    function openDialer(number: string): void {
        if (!number) return
        if (!KdeConnectService.activeReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("Phone is not connected or reachable"), false)
            return
        }
        if (!KdeConnectService.adbReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("ADB is not reachable. Enable Wireless Debugging / USB Debugging."), false)
            return
        }
        if (Config.options?.phone?.contacts?.callDirectly ?? true) {
            PhoneCallService.dial(number)
            return
        }
        root._startIntent("android.intent.action.DIAL", "tel:" + encodeURIComponent(number),
            Translation.tr("Opening dialer for %1…").arg(number))
    }

    /** The digits WhatsApp expects: country code, area code, number. What the
     *  contact already has is kept: a leading "+" or an international prefix
     *  means the number is complete. Only what is missing is added from the
     *  settings: the area code in front of a bare 8 or 9 digit number, then
     *  the country code in front of anything that does not start with it. The
     *  contact itself is never changed. */
    function whatsappNumber(number: string): string {
        const raw = String(number || "").trim()
        let digits = raw.replace(/\D/g, "")
        if (digits.length === 0) return ""
        if (raw.startsWith("+")) return digits
        if (digits.startsWith("00")) return digits.substring(2)
        const cc = String(Config.options?.phone?.contacts?.whatsappCountryCode ?? "55").replace(/\D/g, "")
        const area = String(Config.options?.phone?.contacts?.whatsappAreaCode ?? "19").replace(/\D/g, "")
        digits = digits.replace(/^0+/, "")
        if (digits.length <= 9 && area.length > 0) digits = area + digits
        if (cc.length > 0 && !(digits.startsWith(cc) && digits.length >= 12)) digits = cc + digits
        return digits
    }

    /** Brings the open WhatsApp window forward, or opens WhatsApp Web. */
    function focusWhatsApp(): void {
        const existing = (HyprlandData.windowList || []).find(w =>
            w && String(w.title || "").startsWith("WhatsApp") && w.address)
        if (existing) Hyprland.dispatch(`hl.dsp.focus({window = "address:${existing.address}"})`)
        else Quickshell.execDetached(["xdg-open", "https://web.whatsapp.com"])
    }

    /** Opens the chat in WhatsApp Web. When a window already showing WhatsApp
     *  exists it is focused and sent to the chat's address, rather than the
     *  browser opening one more tab (and WhatsApp Web insisting it is already
     *  open somewhere else). */
    function openWhatsApp(number: string): void {
        root.openWhatsAppWithText(number, "")
    }

    /** Same, with `text` typed into the chat's message box and, unless turned
     *  off in the settings, sent. */
    function openWhatsAppWithText(number: string, text: string): void {
        const n = root.whatsappNumber(number)
        if (n.length === 0) return
        const message = String(text ?? "").trim()
        const url = "https://web.whatsapp.com/send?phone=" + n
            + (message.length > 0 ? "&text=" + encodeURIComponent(message) : "")

        // An open sidebar holds the keyboard (its focus grab), so keystrokes
        // meant for the browser landed in the sidebar's own message box. Let
        // it go unless it is pinned, which does not take the keyboard.
        if (!GlobalStates.sidebarLeftPinned) GlobalStates.sidebarLeftOpen = false

        const existing = (HyprlandData.windowList || []).find(w =>
            w && String(w.title || "").startsWith("WhatsApp") && w.address)
        const autoSend = message.length > 0 && (Config.options?.phone?.contacts?.whatsappAutoSend ?? true)
        const delay = Math.max(1, Number(Config.options?.phone?.contacts?.whatsappSendDelay ?? 6))
        // The script checks that WhatsApp is the focused window before every
        // keystroke, and falls back to opening the link in the browser
        Quickshell.execDetached(["bash",
            FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/phone/whatsapp-send.sh")),
            url, autoSend ? "1" : "0", String(delay), existing ? String(existing.address) : ""])
        KdeConnectService.dispatchActionFeedback(Translation.tr("Opening WhatsApp for %1…").arg(number), true)
    }

    function composeSms(number: string): void {
        if (!number) return
        if (!KdeConnectService.activeReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("Phone is not connected or reachable"), false)
            return
        }
        if (!KdeConnectService.adbReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("ADB is not reachable. Enable Wireless Debugging / USB Debugging."), false)
            return
        }
        root._startIntent("android.intent.action.SENDTO", "sms:" + encodeURIComponent(number),
            Translation.tr("Opening SMS for %1…").arg(number))
    }

    /** Fires an `am start` on the phone. The ADB target is re-resolved first
     *  because the wireless-debugging port changes on every toggle/reboot,
     *  and a stale serial makes the intent vanish with no error. */
    function _startIntent(action: string, uri: string, feedback: string): void {
        KdeConnectService.withAdbTarget(targetArgs => {
            const cmd = ["adb"].concat(targetArgs || [])
            cmd.push("shell", "am", "start", "-a", action, "-d", uri)
            Quickshell.execDetached(cmd)
            KdeConnectService.dispatchActionFeedback(feedback, true)
        })
    }

    function toggleFavorite(contactId: string): void {
        if (!contactId) return
        let currentFavs = (Config.options?.phone?.contacts?.favoriteIds || []).slice()
        const idx = currentFavs.indexOf(contactId)
        if (idx >= 0) {
            currentFavs.splice(idx, 1)
        } else {
            currentFavs.push(contactId)
        }
        Config.options.phone.contacts.favoriteIds = currentFavs
        root._updateFilteredContacts()
    }

    function isFavorite(contactId: string): bool {
        if (!contactId) return false
        const favs = Config.options?.phone?.contacts?.favoriteIds || []
        return favs.indexOf(contactId) >= 0
    }

    // A contact is nameless when the vCard had no name, organization, or any
    // other human-readable field — only a number. Favorites are always kept:
    // starring one is an explicit statement that it matters.
    function _isNameless(contact: var): bool {
        if (!contact || contact.nameless !== true) return false
        return !root.isFavorite(contact.id)
    }

    function _updateFilteredContacts(): void {
        if (!contacts) {
            filteredContacts = []
            root.hiddenCount = 0
            return
        }
        const base = root.hideUnnamed ? contacts.filter(c => !root._isNameless(c)) : contacts
        root.hiddenCount = contacts.length - base.length

        const q = searchQuery.trim().toLowerCase()
        if (!q) {
            filteredContacts = base
            return
        }
        const cleanQ = q.replace(/[\s\-\(\)\.]/g, "")
        filteredContacts = base.filter(c => {
            if (!c) return false
            if (c.displayName && c.displayName.toLowerCase().includes(q)) return true
            if (c.organization && c.organization.toLowerCase().includes(q)) return true

            if (c.phones) {
                for (let i = 0; i < c.phones.length; i++) {
                    const p = c.phones[i]
                    if (p.value && p.value.toLowerCase().includes(q)) return true
                    if (p.normalized && cleanQ && p.normalized.includes(cleanQ)) return true
                }
            }
            if (c.emails) {
                for (let i = 0; i < c.emails.length; i++) {
                    if (c.emails[i].value && c.emails[i].value.toLowerCase().includes(q)) return true
                }
            }
            return false
        })
    }

    onContactsChanged: root._updateFilteredContacts()

    IpcHandler {
        target: "phoneContacts"
        function refresh() {
            root.refresh()
        }
        function search(query: string) {
            root.setSearchQuery(query)
        }
    }

    // The contacts monitor used to run as a permanently resident Python interpreter whose only job
    // was to sit in a GLib main loop and re-read a directory of .vcf files. `gio monitor` is that
    // exact same GFileMonitor (glib2, already a hard Qt dependency) at a fraction of the memory,
    // and the script's own --once mode produces byte-identical `ready` + `snapshot` output. The
    // 250 ms debounce and the "only publish when the payload changed" rule are the daemon's.
    readonly property bool _enabled: Config.options?.phone?.contacts?.enabled ?? true
    property bool _watching: false
    property bool _forceEmit: false
    property string _lastSnapshot: ""
    property bool _usePolling: false

    function _readOnce(): void {
        readProcess.running = false
        readProcess.running = true
    }

    on_EnabledChanged: {
        if (root._enabled) {
            root._readOnce()
        } else {
            root._watching = false
            root._usePolling = false
        }
    }

    Component.onCompleted: {
        if (root._enabled)
            root._readOnce()
    }

    Timer {
        // Debounce bursts of writes the same way the daemon's GLib timeout did.
        id: changeDebounce
        interval: 250
        repeat: false
        onTriggered: root._readOnce()
    }

    Timer {
        // The script falls back to a 3 s poll when it cannot watch; so does this.
        id: pollTimer
        interval: 3000
        repeat: true
        running: root._enabled && root._usePolling
        onTriggered: root._readOnce()
    }

    Timer {
        // gio ships with glib2 and should always be there, but if it is not, poll instead of
        // silently never noticing a contact change again.
        id: watchStartCheck
        interval: 1000
        repeat: false
        onTriggered: {
            if (root._watching && !watchProcess.running)
                root._usePolling = true
        }
    }

    Process {
        id: watchProcess
        command: ProcUtils.pdeath(["gio", "monitor", "-d", root.sourcePath])
        running: root._enabled && root._watching && !root._usePolling && root.sourcePath !== ""

        onRunningChanged: {
            if (running)
                root._usePolling = false
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    changeDebounce.restart()
            }
        }
    }

    Process {
        id: readProcess
        command: [
            "python3",
            Quickshell.shellPath("scripts/kdeconnect/contacts_monitor.py"),
            "--device", KdeConnectService.activeDeviceId || "",
            "--once"
        ]
        running: false

        onExited: root._forceEmit = false

        stdout: SplitParser {
            onRead: data => {
                try {
                    const msg = JSON.parse(data)
                    if (msg.event === "ready") {
                        root.available = true
                        root.ready = true
                        root.sourcePath = msg.sourcePath || ""
                        root.lastError = ""
                        if (!root._watching) {
                            root._watching = true
                            watchStartCheck.restart()
                        }
                    } else if (msg.event === "snapshot") {
                        const payload = JSON.stringify(msg.contacts || [])
                        if (root._forceEmit || payload !== root._lastSnapshot) {
                            root._lastSnapshot = payload
                            root.contacts = msg.contacts || []
                        }
                    } else if (msg.event === "error") {
                        root.lastError = msg.message || "Unknown contacts error"
                        if (msg.code === "no_contact_source") {
                            root.ready = false
                        }
                    }
                } catch (e) {
                    console.warn("[PhoneContactsService] JSON parse error:", e, "Line:", data)
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim().length > 0) {
                    console.warn("[PhoneContactsService stderr]", data)
                }
            }
        }
    }
}
