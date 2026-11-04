pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/**
 * Provides extra features not in Quickshell.Services.Notifications:
 *  - Persistent storage
 *  - Popup notifications, with timeout
 *  - Notification groups by app
 */
Singleton {
	id: root
    component Notif: QtObject {
        id: wrapper
        required property int notificationId // Could just be `id` but it conflicts with the default prop in QtObject
        property Notification notification
        property list<var> actions: notification?.actions.map((action) => ({
            "identifier": action.identifier,
            "text": action.text,
        })) ?? []
        property bool popup: false
        property bool isTransient: notification?.hints.transient ?? false
        // Reposted from the phone by KdeConnectService, which tags it with these hints.
        property bool isPhone: !!(notification && notification.hints && notification.hints["x-ii-source"] === "phone")
        property string phoneId: (notification && notification.hints && notification.hints["x-ii-phone-id"]) ? String(notification.hints["x-ii-phone-id"]) : ""
        property string phoneDevice: (notification && notification.hints && notification.hints["x-ii-phone-device"]) ? String(notification.hints["x-ii-phone-device"]) : ""
        property string appIcon: notification?.appIcon ?? ""
        property string appName: notification?.appName ?? ""
        property string body: notification?.body ?? ""
        property string image: notification?.image ?? ""
        property string summary: notification?.summary ?? ""
        property double time
        property string urgency: notification?.urgency.toString() ?? "normal"
        property Timer timer

        onNotificationChanged: {
            if (notification === null) {
                root.discardNotification(notificationId);
            }
        }
    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
            "isPhone": notif.isPhone,
            "phoneId": notif.phoneId,
            "phoneDevice": notif.phoneDevice,
        }
    }
    function notifToString(notif) {
        return JSON.stringify(notifToJSON(notif), null, 2);
    }

    component NotifTimer: Timer {
        required property int notificationId
        interval: 7000
        running: true
        onTriggered: () => {
            const index = root.list.findIndex((notif) => notif.notificationId === notificationId);
            const notifObject = root.list[index];
            print("[Notifications] Notification timer triggered for ID: " + notificationId + ", transient: " + notifObject?.isTransient);
            if (notifObject.isTransient) root.discardNotification(notificationId);
            else root.timeoutNotification(notificationId);
            destroy()
        }
    }

    property bool silent: false
    property int unread: 0
    property var filePath: Directories.notificationsPath
    property list<Notif> list: []
    property var popupList: list.filter((notif) => notif.popup);
    property bool popupInhibited: (GlobalStates?.sidebarRightOpen ?? false) || silent
    property var latestTimeForApp: ({})
    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    function stringifyList(list) {
        return JSON.stringify(list.map((notif) => notifToJSON(notif)), null, 2);
    }
    
    onListChanged: {
        // Update latest time for each app
        root.list.forEach((notif) => {
            const key = root.groupKey(notif);
            if (!root.latestTimeForApp[key] || notif.time > root.latestTimeForApp[key]) {
                root.latestTimeForApp[key] = Math.max(root.latestTimeForApp[key] || 0, notif.time);
            }
        });
        // Remove apps that no longer have notifications
        Object.keys(root.latestTimeForApp).forEach((key) => {
            if (!root.list.some((notif) => root.groupKey(notif) === key)) {
                delete root.latestTimeForApp[key];
            }
        });
    }

    // A phone's "WhatsApp" and the computer's are different groups.
    function groupKey(notif) {
        return (notif.isPhone ? "phone\u0001" : "") + notif.appName;
    }

    // This computer's groups first, then the phone's, each newest first
    function sortedGroupKeys(groups) {
        return Object.keys(groups).sort((a, b) => {
            if (groups[a].isPhone !== groups[b].isPhone) return groups[a].isPhone ? 1 : -1;
            return groups[b].time - groups[a].time;
        });
    }

    function appNameListForGroups(groups) {
        return sortedGroupKeys(groups);
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif) => {
            const key = groupKey(notif);
            if (!groups[key]) {
                groups[key] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    isPhone: notif.isPhone,
                    notifications: [],
                    time: 0
                };
            }
            groups[key].notifications.push(notif);
            // Always set to the latest time in the group
            groups[key].time = latestTimeForApp[key] || notif.time;
        });
        // The list shows a heading where the computer's groups end and the phone's begin.
        // The computer's only gets one when there is a phone section to tell it from.
        const keys = sortedGroupKeys(groups);
        const hasPhone = keys.some((k) => groups[k].isPhone);
        keys.forEach((k, i) => {
            const g = groups[k];
            const starts = i === 0 || groups[keys[i - 1]].isPhone !== g.isPhone;
            g.showHeader = starts && (g.isPhone || hasPhone);
            g.sectionTitle = g.isPhone ? Translation.tr("Phone") : Translation.tr("This computer");
        });
        return groups;
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property list<string> appNameList: appNameListForGroups(root.groupsByAppName)
    property list<string> popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    signal initDone();
    signal notify(notification: var);
    signal discard(id: int);
    signal discardAll();
    signal timeout(id: var);

	NotificationServer {
        id: notifServer
        // actionIconsSupported: true
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            // KDE Connect's own desktop copy of a phone notification (and its other chatter)
            // is not shown: the phone's notifications arrive reposted, grouped by their app
            // and with Open/Reply buttons. The outgoing-transfer result is the one thing
            // handed back, as a notification of the shell's own.
            if (/kde\s*connect/i.test(notification.appName || "")) {
                KdeConnectService.considerTransferNotification(notification);
                return;
            }
            notification.tracked = true
            // A conversation that got a new message replaces its older entry instead of piling up
            if (notification.hints && notification.hints["x-ii-source"] === "phone" && notification.hints["x-ii-phone-id"]) {
                const pid = String(notification.hints["x-ii-phone-id"]);
                const dev = String(notification.hints["x-ii-phone-device"] || "");
                root.list.filter((n) => n.isPhone && n.phoneId === pid && n.phoneDevice === dev)
                    .forEach((n) => root.discardNotification(n.notificationId));
            }
            const newNotifObject = notifComponent.createObject(root, {
                "notificationId": notification.id + root.idOffset,
                "notification": notification,
                "time": Date.now(),
            });
			root.list = [...root.list, newNotifObject];

            // Popup
            if (!root.popupInhibited) {
                newNotifObject.popup = true;
                if (notification.expireTimeout != 0) {
                    newNotifObject.timer = notifTimerComponent.createObject(root, {
                        "notificationId": newNotifObject.notificationId,
                        "interval": notification.expireTimeout < 0 ? (Config?.options.notifications.timeout ?? 7000) : notification.expireTimeout,
                    });
                }
                root.unread++;
            }
            root.notify(newNotifObject);
            // console.log(notifToString(newNotifObject));
            notifFileView.setText(stringifyList(root.list));
        }
    }

    function markAllRead() {
        root.unread = 0;
    }

    function discardNotification(id) {
        console.log("[Notifications] Discarding notification with ID: " + id);
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id + root.idOffset === id);
        if (index !== -1) {
            root.list.splice(index, 1);
            notifFileView.setText(stringifyList(root.list));
            triggerListChange()
        }
        if (notifServerIndex !== -1) {
            notifServer.trackedNotifications.values[notifServerIndex].dismiss()
        }
        root.discard(id); // Emit signal
    }

    function discardAllNotifications() {
        root.list = []
        triggerListChange()
        notifFileView.setText(stringifyList(root.list));
        notifServer.trackedNotifications.values.forEach((notif) => {
            notif.dismiss()
        })
        root.discardAll();
    }

    function cancelTimeout(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].timer.stop();
    }

    function timeoutNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].popup = false;
        root.timeout(id);
    }

    function timeoutAll() {
        root.popupList.forEach((notif) => {
            root.timeout(notif.notificationId);
        })
        root.popupList.forEach((notif) => {
            notif.popup = false;
        });
    }

    function attemptInvokeAction(id, notifIdentifier) {
        console.log("[Notifications] Attempting to invoke action with identifier: " + notifIdentifier + " for notification ID: " + id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id + root.idOffset === id);
        console.log("Notification server index: " + notifServerIndex);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find((action) => action.identifier === notifIdentifier);
            // console.log("Action found: " + JSON.stringify(action));
            action.invoke()
        } 
        else {
            console.log("Notification not found in server: " + id)
        }
        root.discardNotification(id);
    }

    function triggerListChange() {
        root.list = root.list.slice(0)
    }

    // Removes the phone's notifications (all of them, or only one app's) in a single pass
    function discardPhoneNotifications(appName) {
        const gone = root.list.filter((n) => n.isPhone && (appName === undefined || n.appName === appName));
        if (gone.length === 0) return;
        const goneIds = new Set(gone.map((n) => n.notificationId));
        root.list = root.list.filter((n) => !goneIds.has(n.notificationId));
        notifFileView.setText(stringifyList(root.list));
        notifServer.trackedNotifications.values.forEach((sn) => {
            if (goneIds.has(sn.id + root.idOffset)) sn.dismiss();
        });
        gone.forEach((n) => root.discard(n.notificationId));
    }

    // Phone notifications older than the configured number of hours leave on their own
    function expirePhoneNotifications() {
        const hours = Config.options.phone?.notifications?.autoClearHours ?? 0;
        if (!(hours > 0)) return;
        const cutoff = Date.now() - hours * 3600 * 1000;
        const stale = root.list.filter((n) => n.isPhone && n.time < cutoff);
        if (stale.length === 0) return;
        const staleIds = new Set(stale.map((n) => n.notificationId));
        root.list = root.list.filter((n) => !staleIds.has(n.notificationId));
        notifFileView.setText(stringifyList(root.list));
        notifServer.trackedNotifications.values.forEach((sn) => {
            if (staleIds.has(sn.id + root.idOffset)) sn.dismiss();
        });
        stale.forEach((n) => root.discard(n.notificationId));
    }

    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.expirePhoneNotifications()
    }

    function refresh() {
        notifFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: notifFileView
        path: Qt.resolvedUrl(filePath)
        onLoaded: {
            const fileContents = notifFileView.text()
            root.list = JSON.parse(fileContents).map((notif) => {
                return notifComponent.createObject(root, {
                    "notificationId": notif.notificationId,
                    "actions": [], // Notification actions are meaningless if they're not tracked by the server or the sender is dead
                    "appIcon": notif.appIcon,
                    "appName": notif.appName,
                    "body": notif.body,
                    "image": notif.image,
                    "summary": notif.summary,
                    "time": notif.time,
                    "urgency": notif.urgency,
                    "isPhone": notif.isPhone === true,
                    "phoneId": notif.phoneId || "",
                    "phoneDevice": notif.phoneDevice || "",
                });
            });
            // KDE Connect's own copies, kept by earlier versions, are no longer shown
            root.list = root.list.filter((notif) => !/kde\s*connect/i.test(notif.appName || ""));
            // Find largest notificationId
            let maxId = 0
            root.list.forEach((notif) => {
                maxId = Math.max(maxId, notif.notificationId)
            })

            console.log("[Notifications] File loaded")
            root.idOffset = maxId
            root.initDone()
            root.expirePhoneNotifications()
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[Notifications] File not found, creating new file.")
                root.list = []
                notifFileView.setText(stringifyList(root.list));
            } else {
                console.log("[Notifications] Error loading file: " + error)
            }
        }
    }
}
