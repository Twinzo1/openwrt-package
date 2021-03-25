module("luci.controller.AdGuardHome1",package.seeall)
local fs=require"nixio.fs"
local http=require"luci.http"
local uci=require"luci.model.uci".cursor()
function index()
entry({"admin", "services", "AdGuardHome1"},alias("admin", "services", "AdGuardHome1", "base"),_("AdGuardHome1"), 10).dependent = true
entry({"admin", "services", "AdGuardHome1", "base"},cbi("AdGuardHome1/base"),_("Base Setting"),1).leaf = true
entry({"admin", "services", "AdGuardHome1", "log"},form("AdGuardHome1/log"),_("Log"),2).leaf = true
entry({"admin", "services", "AdGuardHome1", "manual"},cbi("AdGuardHome1/manual"),_("Manual Config"),3).leaf = true
entry({"admin", "services", "AdGuardHome1", "status"},call("act_status")).leaf=true
entry({"admin", "services", "AdGuardHome1", "check"}, call("check_update"))
entry({"admin", "services", "AdGuardHome1", "doupdate"}, call("do_update"))
entry({"admin", "services", "AdGuardHome1", "getlog"}, call("get_log"))
entry({"admin", "services", "AdGuardHome1", "dodellog"}, call("do_dellog"))
entry({"admin", "services", "AdGuardHome1", "reloadconfig"}, call("reload_config"))
entry({"admin", "services", "AdGuardHome1", "gettemplateconfig"}, call("get_template_config"))
end 
function get_template_config()
	local b
	local d=""
	local RESCONF=uci:get_first("dhcp","dnsmasq","resolvfile") or "/tmp/resolv.conf.d/resolv.conf.auto"
	for cnt in io.lines(RESCONF) do
		b=string.match (cnt,"^[^#]*nameserver%s+([^%s]+)$")
		if (b~=nil) then
			d=d.."  - "..b.."\n"
		end
	end
	local f=io.open("/usr/share/AdGuardHome1/AdGuardHome_template.yaml", "r+")
	local tbl = {}
	local a=""
	while (1) do
    	a=f:read("*l")
		if (a=="#bootstrap_dns") then
			a=d
		elseif (a=="#upstream_dns") then
			a=d
		elseif (a==nil) then
			break
		end
		table.insert(tbl, a)
	end
	f:close()
	http.prepare_content("text/plain; charset=utf-8")
	http.write(table.concat(tbl, "\n"))
end
function reload_config()
	fs.remove("/tmp/AdGuardHome1tmpconfig.yaml")
	http.prepare_content("application/json")
	http.write('')
end
function act_status()
	local e={}
	local binpath=uci:get("AdGuardHome1","AdGuardHome","binpath")
	e.running=luci.sys.call("pgrep "..binpath.." >/dev/null")==0
	e.redirect=(fs.readfile("/var/run/AdGredir1")=="1")
	http.prepare_content("application/json")
	http.write_json(e)
end
function do_update()
	fs.writefile("/var/run/lucilogpos1","0")
	http.prepare_content("application/json")
	http.write('')
	local arg
	if luci.http.formvalue("force") == "1" then
		arg="force"
	else
		arg=""
	end
	if fs.access("/var/run/update_core1") then
		if arg=="force" then
			luci.sys.exec("kill $(pgrep /usr/share/AdGuardHome1/update_core.sh) ; sh /usr/share/AdGuardHome1/update_core.sh "..arg.." >/tmp/AdGuardHome1_update.log 2>&1 &")
		end
	else
		luci.sys.exec("sh /usr/share/AdGuardHome1/update_core.sh "..arg.." >/tmp/AdGuardHome1_update.log 2>&1 &")
	end
end
function get_log()
	local logfile=uci:get("AdGuardHome1","AdGuardHome","logfile")
	if (logfile==nil) then
		http.write("no log available\n")
		return
	elseif (logfile=="syslog") then
		if not fs.access("/var/run/AdGuardHome1syslog") then
			luci.sys.exec("(/usr/share/AdGuardHome1/getsyslog.sh &); sleep 1;")
		end
		logfile="/tmp/AdGuardHome1tmp.log"
		fs.writefile("/var/run/AdGuardHome1syslog","1")
	elseif not fs.access(logfile) then
		http.write("")
		return
	end
	http.prepare_content("text/plain; charset=utf-8")
	local fdp
	if fs.access("/var/run/lucilogreload1") then
		fdp=0
		fs.remove("/var/run/lucilogreload1")
	else
		fdp=tonumber(fs.readfile("/var/run/lucilogpos1")) or 0
	end
	local f=io.open(logfile, "r+")
	f:seek("set",fdp)
	local a=f:read(2048000) or ""
	fdp=f:seek()
	fs.writefile("/var/run/lucilogpos1",tostring(fdp))
	f:close()
	http.write(a)
end
function do_dellog()
	local logfile=uci:get("AdGuardHome1","AdGuardHome","logfile")
	fs.writefile(logfile,"")
	http.prepare_content("application/json")
	http.write('')
end
function check_update()
	http.prepare_content("text/plain; charset=utf-8")
	local fdp=tonumber(fs.readfile("/var/run/lucilogpos1")) or 0
	local f=io.open("/tmp/AdGuardHome1_update.log", "r+")
	f:seek("set",fdp)
	local a=f:read(2048000) or ""
	fdp=f:seek()
	fs.writefile("/var/run/lucilogpos1",tostring(fdp))
	f:close()
if fs.access("/var/run/update_core1") then
	http.write(a)
else
	http.write(a.."\0")
end
end
