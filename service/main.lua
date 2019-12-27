local skynet = require "skynet"

skynet.start(function()
	skynet.error("Server start")	
	--if not skynet.getenv "daemon" then
		--local console = skynet.newservice("console")
	--end
	skynet.newservice("debug_console",8000)
	
	local loginserver = skynet.newservice("logind")
	local platform_id = 1
	local server_id = 1
	local gate = skynet.newservice("gated", loginserver, platform_id, server_id)
	skynet.call(gate, "lua", "open" , {
		port = 8102,
		maxclient = 512,
		servername = "DevelopServer",
	})

	
		
	skynet.exit()
end)
