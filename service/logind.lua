local login = require "snax.loginserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
require "Common.Util.util"

local server = {
	host = "0.0.0.0",
	port = 8101,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

local server_list = {}
local user_online = {}
local user_login = {}

function server.auth_handler(token)
	-- the token is base64(user)@base64(server):base64(password)
	local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	server = crypt.base64decode(server)
	password = crypt.base64decode(password)
	print('Cat:logind.lua[22] user, password', user, password)
	
	local accountServer = skynet.localname(".AccountDBServer")
	local result = skynet.call(accountServer, "lua", "findOne", "accounts", {account_name=user})
	local player_id = 0
	if result then
		--assert(passowrd==result.password, "Invalid password")
		player_id = result.account_id
	else
		local doc = skynet.call(accountServer, "lua", "findAndModify", "sequence", 
		{
			query = {_id = "sequence_id"},
			update = {["$inc"] = {sequence_value = 1}},
			new = true,
		})
		skynet.error("query sequence"..doc["sequence_value"])
		skynet.call(accountServer, "lua", "insert", "accounts", 
		{
			account_name=user, 
			account_id=doc["sequence_value"],
			password=password,
		})

		player_id = doc["sequence_value"]
	end

	skynet.error("login succeed with player_id = "..player_id)
	skynet.error("login succeed with user = "..user)
	return server, user
end

function server.login_handler(server, uid, secret)
	print(string.format("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))
	local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	if last then
		skynet.call(last.address, "lua", "kick", uid, last.subid)
	end
	if user_online[uid] then
		error(string.format("user %s is already online", uid))
	end

	local subid = tostring(skynet.call(gameserver, "lua", "login", uid, secret))
	user_online[uid] = { address = gameserver, subid = subid , server = server}
	return subid
end

local CMD = {}

function CMD.register_gate(server, address)
	server_list[server] = address
end

function CMD.logout(uid, subid)
	local u = user_online[uid]
	if u then
		print(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(server)
