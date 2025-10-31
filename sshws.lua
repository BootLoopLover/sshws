module("luci.controller.sshws", package.seeall)

function index()
    -- Daftarkan entri menu di bawah 'Services'
    entry({"admin", "services", "sshws"}, call("action_sshws"), _("SSHWS Tunnel"), 100).leaf = true
end

function action_sshws()
    local fs = require "nixio.fs"
    local json = require "luci.jsonc"
    local sys = require "luci.sys"
    local http = require "luci.http"
    local socket = require "nixio.socket"

    local config_path = "/root/config.json"
    local cfg = {}
    local message = nil

    -- Baca konfigurasi semasa
    if fs.access(config_path) then
        local content = fs.readfile(config_path)
        if content and content ~= "" then
            cfg = json.parse(content) or {}
        end
    end

    if not cfg.ssh then
        cfg.ssh = {}
    end

    local action = http.formvalue("action")

    if action == "reload" then
        http.redirect(luci.dispatcher.build_url("admin/services/run"))
        return

    elseif action == "save" then
        local newcfg = {
            mode = http.formvalue("mode") or "proxy",
            proxyHost = http.formvalue("proxyHost") or "",
            proxyPort = http.formvalue("proxyPort") or "80",
            ssh = {
                host = http.formvalue("ssh_host") or "",
                port = tonumber(http.formvalue("ssh_port")) or 22,
                username = http.formvalue("ssh_username") or "",
                password = http.formvalue("ssh_password") or ""
            },
            httpPayload = http.formvalue("httpPayload") or "",
            connectionTimeout = tonumber(http.formvalue("connectionTimeout")) or 30
        }

        fs.writefile(config_path, json.stringify(newcfg))
        cfg = newcfg
        message = "✅ Konfigurasi disimpan ke /root/config.json"

    elseif action == "start" then
        -- Mulakan semula servis
        sys.call("/etc/init.d/run restart >/dev/null 2>&1 &")
        luci.sys.exec("sleep 2") -- beri masa servis untuk mula

        -- Semak proses
        local pid = luci.sys.exec("pgrep -f sshws")
        if pid and pid ~= "" then
            -- Tambahan: semak sambungan TCP
            local host = cfg.ssh.host or "127.0.0.1"
            local port = cfg.ssh.port or 22
            local s = socket.connect(host, port)

            if s then
                s:close()
                message = string.format("🟢 SSHWS tersambung ke %s:%d", host, port)
            else
                message = string.format("🟠 SSHWS berjalan tetapi gagal sambung ke %s:%d", host, port)
            end
        else
            message = "🔴 SSHWS gagal dimulakan"
        end

    elseif action == "stop" then
        sys.call("/etc/init.d/run stop >/dev/null 2>&1 &")
        message = "🔴 SSHWS dihentikan"
    end

    luci.template.render("sshws", { cfg = cfg, message = message })
end
