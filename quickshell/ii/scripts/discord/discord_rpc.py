#!/usr/bin/env python3
"""Voice side of the Discord desktop app, over its local IPC socket (RPC).

Talks to the running Discord client through $XDG_RUNTIME_DIR/discord-ipc-N, as
an app of the user's own (client id + secret from the Discord developer
portal, the user's account added as a tester). It never touches the account
token and never sends or reads chat messages.

stdout: one JSON object per line, always the whole state:
  {"type": "state", "connected", "authorized", "status", "error", "user",
   "guilds", "guildId", "channels", "voice", "settings"}
stdin: one JSON command per line:
  {"cmd": "selectGuild", "id": "..."} | {"cmd": "join", "id": "..."} | {"cmd": "leave"}
  {"cmd": "setMute", "value": true} | {"cmd": "setDeaf", "value": true}
  {"cmd": "setVolume", "which": "input"|"output", "value": 0..100}
  {"cmd": "setDevice", "which": "input"|"output", "id": "<device id from settings.*Devices>"}
  {"cmd": "setUserVolume", "id": "...", "value": 0..200} | {"cmd": "muteUser", "id": "...", "value": true}
  {"cmd": "refresh"} | {"cmd": "authorize"}
"""
import argparse
import asyncio
import json
import os
import struct
import sys
import urllib.parse
import urllib.request
import uuid

OP_HANDSHAKE, OP_FRAME, OP_CLOSE, OP_PING, OP_PONG = 0, 1, 2, 3, 4
SCOPES = ["rpc", "rpc.voice.read", "rpc.voice.write"]
DEBUG = os.environ.get("DISCORD_RPC_DEBUG") == "1"
TOKEN_URL = os.environ.get("DISCORD_TOKEN_URL", "https://discord.com/api/oauth2/token")


def socket_candidates():
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    bases = [runtime,
             os.path.join(runtime, "app/com.discordapp.Discord"),
             os.path.join(runtime, "app/com.discordapp.DiscordCanary"),
             os.path.join(runtime, "snap.discord"),
             os.path.join(runtime, "snap.discord-canary")]
    for base in bases:
        for i in range(10):
            yield os.path.join(base, f"discord-ipc-{i}")


class Client:
    def __init__(self, args):
        self.args = args
        self.reader = None
        self.writer = None
        self.pending = {}
        self.token = self._load_token()
        self.state = {
            "type": "state", "connected": False, "authorized": False,
            "status": "starting", "error": "", "user": None, "guilds": [],
            "guildId": "", "channels": [], "voice": None,
            "settings": {"mute": False, "deaf": False, "input": 100, "output": 100,
                         "inputDevice": "", "outputDevice": "", "inputDevices": [], "outputDevices": []},
        }
        self.users = {}          # user id -> user entry of the current channel
        self.voice_channel = None
        self.want_guild = ""
        self.ready = asyncio.Event()
        self.tasks = set()       # fire-and-forget tasks: asyncio only holds them weakly

    def spawn(self, coro):
        task = asyncio.create_task(coro)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)
        return task

    # ── output ───────────────────────────────────────────────────────────
    def emit(self):
        voice = None
        if self.voice_channel:
            voice = dict(self.voice_channel)
            voice["users"] = list(self.users.values())
        self.state["voice"] = voice
        sys.stdout.write(json.dumps(self.state, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    def fail(self, message):
        self.state["error"] = message
        self.emit()

    # ── token file ───────────────────────────────────────────────────────
    def _load_token(self):
        try:
            with open(self.args.token_file) as f:
                return json.load(f)
        except Exception:
            return {}

    def _save_token(self):
        os.makedirs(os.path.dirname(self.args.token_file), exist_ok=True)
        with open(self.args.token_file, "w") as f:
            json.dump(self.token, f)
        os.chmod(self.args.token_file, 0o600)

    def _exchange(self, params):
        params = dict(params, client_id=self.args.client_id, client_secret=self.args.client_secret)
        data = urllib.parse.urlencode(params).encode()
        req = urllib.request.Request(TOKEN_URL, data=data, headers={
            "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "ii-discord-voice"})
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())

    async def exchange(self, params):
        return await asyncio.get_running_loop().run_in_executor(None, self._exchange, params)

    # ── ipc framing ──────────────────────────────────────────────────────
    async def connect(self):
        for path in socket_candidates():
            if not os.path.exists(path):
                continue
            try:
                self.reader, self.writer = await asyncio.open_unix_connection(path)
                return True
            except OSError:
                continue
        return False

    async def send(self, op, payload):
        if DEBUG:
            print(f"-> op{op} {json.dumps(payload)[:300]}", file=sys.stderr, flush=True)
        raw = json.dumps(payload).encode()
        self.writer.write(struct.pack("<II", op, len(raw)) + raw)
        await self.writer.drain()

    async def read_frame(self):
        head = await self.reader.readexactly(8)
        op, length = struct.unpack("<II", head)
        body = await self.reader.readexactly(length)
        data = json.loads(body.decode() or "{}")
        if DEBUG:
            print(f"<- op{op} {json.dumps(data)[:300]}", file=sys.stderr, flush=True)
        return op, data

    async def call(self, cmd, args=None, evt=None, timeout=15):
        nonce = str(uuid.uuid4())
        fut = asyncio.get_running_loop().create_future()
        self.pending[nonce] = fut
        payload = {"cmd": cmd, "nonce": nonce, "args": args or {}}
        if evt:
            payload["evt"] = evt
        await self.send(OP_FRAME, payload)
        try:
            return await asyncio.wait_for(fut, timeout)
        finally:
            self.pending.pop(nonce, None)

    # ── session ──────────────────────────────────────────────────────────
    async def session(self):
        self.state.update(connected=False, authorized=False, status="waiting for Discord", user=None)
        self.emit()
        while not await self.connect():
            await asyncio.sleep(3)
        self.ready.clear()
        await self.send(OP_HANDSHAKE, {"v": 1, "client_id": self.args.client_id})
        reader_task = self.spawn(self.read_loop())
        try:
            self.state.update(connected=True, status="connecting", error="")
            self.emit()
            # Commands before READY can be dropped by Discord
            waiter = self.spawn(self.ready.wait())
            done, _ = await asyncio.wait({waiter, reader_task}, timeout=10, return_when=asyncio.FIRST_COMPLETED)
            if reader_task in done:
                reader_task.result()   # Discord closed the connection: its own reason is raised
                raise ConnectionError("Discord closed the connection")
            if waiter not in done:
                waiter.cancel()
                raise ConnectionError("Discord did not answer the handshake (is it the official app?)")
            await self.authenticate()
            await self.bootstrap()
            refresher = self.spawn(self.idle_refresh())
            try:
                await reader_task
            finally:
                refresher.cancel()
        finally:
            reader_task.cancel()
            try:
                self.writer.close()
            except Exception:
                pass
            for fut in self.pending.values():
                if not fut.done():
                    fut.cancel()
            self.pending.clear()

    async def read_loop(self):
        while True:
            op, data = await self.read_frame()
            if op == OP_PING:
                await self.send(OP_PONG, data)
            elif op == OP_CLOSE:
                raise ConnectionError(data.get("message", "closed by Discord"))
            elif op == OP_FRAME:
                nonce = data.get("nonce")
                if nonce in self.pending and not self.pending[nonce].done():
                    self.pending[nonce].set_result(data)
                elif data.get("cmd") == "DISPATCH":
                    if data.get("evt") == "READY":
                        self.ready.set()
                    elif data.get("evt") == "ERROR":
                        raise ConnectionError((data.get("data") or {}).get("message", "error from Discord"))
                    await self.on_event(data.get("evt"), data.get("data") or {})

    async def authenticate(self):
        if not self.args.client_id or not self.args.client_secret:
            self.state.update(status="needs setup", error="Set the client id and secret in Settings")
            self.emit()
            await asyncio.Event().wait()
        access = self.token.get("access_token")
        if access:
            reply = await self.call("AUTHENTICATE", {"access_token": access})
            if reply.get("evt") != "ERROR":
                return self.authenticated(reply)
            if self.token.get("refresh_token"):
                try:
                    self.token = await self.exchange({"grant_type": "refresh_token",
                                                      "refresh_token": self.token["refresh_token"]})
                    self._save_token()
                    reply = await self.call("AUTHENTICATE", {"access_token": self.token["access_token"]})
                    if reply.get("evt") != "ERROR":
                        return self.authenticated(reply)
                except Exception:
                    pass
        await self.authorize()

    async def authorize(self):
        self.state.update(status="waiting for authorization")
        self.emit()
        # Discord shows its own prompt; the reply comes once it is accepted.
        reply = await self.call("AUTHORIZE", {"client_id": self.args.client_id, "scopes": SCOPES}, timeout=300)
        if reply.get("evt") == "ERROR":
            raise PermissionError(reply.get("data", {}).get("message", "authorization refused"))
        code = reply["data"]["code"]
        self.token = await self.exchange({"grant_type": "authorization_code", "code": code,
                                          "redirect_uri": self.args.redirect_uri})
        self._save_token()
        reply = await self.call("AUTHENTICATE", {"access_token": self.token["access_token"]})
        if reply.get("evt") == "ERROR":
            raise PermissionError(reply.get("data", {}).get("message", "authentication refused"))
        self.authenticated(reply)

    def authenticated(self, reply):
        user = (reply.get("data") or {}).get("user") or {}
        self.state.update(authorized=True, status="ready", error="", user=self.user_entry(user))
        self.emit()

    async def bootstrap(self):
        for evt in ("VOICE_SETTINGS_UPDATE", "VOICE_CHANNEL_SELECT"):
            await self.call("SUBSCRIBE", evt=evt)
        await self.load_guilds()
        await self.load_settings()
        await self.load_voice_channel()

    # ── data ─────────────────────────────────────────────────────────────
    @staticmethod
    def user_entry(user):
        uid = str(user.get("id", ""))
        avatar = user.get("avatar")
        return {"id": uid,
                "name": user.get("global_name") or user.get("username") or uid,
                "avatar": f"https://cdn.discordapp.com/avatars/{uid}/{avatar}.png?size=64" if avatar else ""}

    def member_entry(self, vs):
        user = vs.get("user") or {}
        entry = self.user_entry(user)
        entry["name"] = vs.get("nick") or entry["name"]
        state = vs.get("voice_state") or {}
        old = self.users.get(entry["id"], {})
        entry.update(
            mute=bool(state.get("mute") or state.get("self_mute")),
            deaf=bool(state.get("deaf") or state.get("self_deaf")),
            volume=vs.get("volume", old.get("volume", 100)),
            localMute=bool(vs.get("mute", old.get("localMute", False))),
            speaking=old.get("speaking", False),
            me=entry["id"] == (self.state["user"] or {}).get("id"))
        return entry

    async def load_guilds(self):
        reply = await self.call("GET_GUILDS")
        guilds = (reply.get("data") or {}).get("guilds") or []
        self.state["guilds"] = [{"id": str(g["id"]), "name": g.get("name", "")} for g in guilds]
        if not self.want_guild and self.state["guilds"]:
            self.want_guild = self.state["guilds"][0]["id"]
        await self.load_channels()

    async def load_channels(self):
        gid = self.want_guild
        self.state["guildId"] = gid
        self.state["channels"] = []
        if not gid:
            return self.emit()
        reply = await self.call("GET_CHANNELS", {"guild_id": gid})
        channels = [c for c in ((reply.get("data") or {}).get("channels") or []) if c.get("type") == 2][:25]
        out = []
        for c in channels:
            count, members = None, []
            try:
                info = await self.call("GET_CHANNEL", {"channel_id": str(c["id"])}, timeout=5)
                states = (info.get("data") or {}).get("voice_states") or []
                count = len(states)
                for vs in states[:12]:
                    e = self.user_entry(vs.get("user") or {})
                    e["name"] = vs.get("nick") or e["name"]
                    members.append({"name": e["name"], "avatar": e["avatar"]})
            except Exception:
                pass
            out.append({"id": str(c["id"]), "name": c.get("name", ""), "count": count, "users": members})
        self.state["channels"] = out
        self.emit()

    async def load_settings(self):
        reply = await self.call("GET_VOICE_SETTINGS")
        self.apply_settings(reply.get("data") or {})

    def apply_settings(self, d):
        s = self.state["settings"]
        if "mute" in d: s["mute"] = bool(d["mute"])
        if "deaf" in d: s["deaf"] = bool(d["deaf"])
        for which in ("input", "output"):
            part = d.get(which)
            if not isinstance(part, dict):
                continue
            if "volume" in part: s[which] = round(part["volume"])
            if "device_id" in part: s[which + "Device"] = str(part["device_id"])
            if isinstance(part.get("available_devices"), list):
                s[which + "Devices"] = [{"id": str(x.get("id", "")), "name": x.get("name", "")}
                                        for x in part["available_devices"] if isinstance(x, dict)]
        self.emit()

    async def load_voice_channel(self):
        reply = await self.call("GET_SELECTED_VOICE_CHANNEL")
        data = reply.get("data")
        await self.set_voice_channel(data)

    async def set_voice_channel(self, data):
        # Leave the old channel's subscriptions behind
        if self.voice_channel:
            for evt in ("VOICE_STATE_CREATE", "VOICE_STATE_UPDATE", "VOICE_STATE_DELETE", "SPEAKING_START", "SPEAKING_STOP"):
                try:
                    await self.call("UNSUBSCRIBE", {"channel_id": self.voice_channel["id"]}, evt=evt, timeout=3)
                except Exception:
                    pass
        self.users = {}
        if not data:
            self.voice_channel = None
            return self.emit()
        cid = str(data["id"])
        self.voice_channel = {"id": cid, "name": data.get("name", ""), "guildId": str(data.get("guild_id") or "")}
        for vs in data.get("voice_states") or []:
            entry = self.member_entry(vs)
            self.users[entry["id"]] = entry
        for evt in ("VOICE_STATE_CREATE", "VOICE_STATE_UPDATE", "VOICE_STATE_DELETE", "SPEAKING_START", "SPEAKING_STOP"):
            await self.call("SUBSCRIBE", {"channel_id": cid}, evt=evt)
        self.emit()

    async def on_event(self, evt, data):
        if evt == "VOICE_SETTINGS_UPDATE":
            self.apply_settings(data)
        elif evt == "VOICE_CHANNEL_SELECT":
            if data.get("channel_id"):
                self.spawn(self.safe(self.load_voice_channel()))
            else:
                # Not awaited: these call back into Discord, and the read loop
                # that got us here is the one that has to read the answers.
                self.spawn(self.safe(self.left_channel()))
        elif evt in ("VOICE_STATE_CREATE", "VOICE_STATE_UPDATE"):
            entry = self.member_entry(data)
            self.users[entry["id"]] = entry
            self.emit()
        elif evt == "VOICE_STATE_DELETE":
            self.users.pop(str((data.get("user") or {}).get("id", "")), None)
            self.emit()
        elif evt in ("SPEAKING_START", "SPEAKING_STOP"):
            user = self.users.get(str(data.get("user_id", "")))
            if user is not None:
                user["speaking"] = evt == "SPEAKING_START"
                self.emit()

    async def idle_refresh(self):
        # Who is in each voice channel changes without Discord telling us unless we are
        # in one, so while we are not, look again now and then.
        while True:
            await asyncio.sleep(15)
            if self.state["authorized"] and self.voice_channel is None:
                try:
                    await self.load_channels()
                except Exception:
                    pass

    async def left_channel(self):
        await self.set_voice_channel(None)
        await self.load_channels()

    async def safe(self, coro):
        try:
            await coro
        except Exception as exc:
            self.fail(str(exc))

    # ── commands from the shell ──────────────────────────────────────────
    async def command(self, msg):
        cmd = msg.get("cmd")
        if cmd == "selectGuild":
            self.want_guild = str(msg.get("id", ""))
            await self.load_channels()
        elif cmd == "join":
            await self.call("SELECT_VOICE_CHANNEL", {"channel_id": str(msg["id"]), "force": True})
        elif cmd == "leave":
            await self.call("SELECT_VOICE_CHANNEL", {"channel_id": None})
        elif cmd == "setMute":
            await self.call("SET_VOICE_SETTINGS", {"mute": bool(msg["value"])})
        elif cmd == "setDeaf":
            await self.call("SET_VOICE_SETTINGS", {"deaf": bool(msg["value"])})
        elif cmd == "setVolume":
            which = "input" if msg.get("which") == "input" else "output"
            await self.call("SET_VOICE_SETTINGS", {which: {"volume": max(0, min(100, float(msg["value"])))}})
        elif cmd == "setDevice":
            which = "input" if msg.get("which") == "input" else "output"
            await self.call("SET_VOICE_SETTINGS", {which: {"device_id": str(msg["id"])}})
            self.state["settings"][which + "Device"] = str(msg["id"]); self.emit()
        elif cmd == "setUserVolume":
            await self.call("SET_USER_VOICE_SETTINGS", {"user_id": str(msg["id"]), "volume": max(0, min(200, int(msg["value"])))})
            if str(msg["id"]) in self.users:
                self.users[str(msg["id"])]["volume"] = int(msg["value"]); self.emit()
        elif cmd == "muteUser":
            await self.call("SET_USER_VOICE_SETTINGS", {"user_id": str(msg["id"]), "mute": bool(msg["value"])})
            if str(msg["id"]) in self.users:
                self.users[str(msg["id"])]["localMute"] = bool(msg["value"]); self.emit()
        elif cmd == "refresh":
            await self.load_guilds(); await self.load_voice_channel()

    async def stdin_loop(self):
        loop = asyncio.get_running_loop()
        reader = asyncio.StreamReader()
        await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        while True:
            line = await reader.readline()
            if not line:
                os._exit(0)
            try:
                msg = json.loads(line.decode())
            except ValueError:
                continue
            if self.writer is None or not self.state["authorized"]:
                continue
            self.spawn(self.safe(self.command(msg)))

    async def run(self):
        self.spawn(self.stdin_loop())
        while True:
            try:
                await self.session()
            except asyncio.CancelledError:
                raise
            except PermissionError as exc:
                self.state["error"] = str(exc)
            except Exception as exc:
                self.state["error"] = str(exc) or exc.__class__.__name__
            self.state.update(connected=False, authorized=False, status="reconnecting")
            self.voice_channel = None
            self.users = {}
            self.emit()
            await asyncio.sleep(4)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--client-id", default="")
    p.add_argument("--client-secret", default="")
    p.add_argument("--redirect-uri", default="http://127.0.0.1")
    p.add_argument("--token-file", default=os.path.expanduser("~/.local/state/quickshell/user/discord_rpc.json"))
    args = p.parse_args()
    try:
        asyncio.run(Client(args).run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
