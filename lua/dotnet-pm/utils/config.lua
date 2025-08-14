--- dotnet-pm.utils.config
-- Centralized config for dotnet-pm.nvim

local M = {}

--- Default config (add more options as needed)
local defaults = {
	exclude_exts = {}, -- e.g. {[".dll"]=true, [".exe"]=true}
	explorer_width = 40, --
}

local config = vim.deepcopy(defaults)

--- Setup (merge user options)
-- @param user_opts table|nil User-supplied options
function M.setup(user_opts)
	if user_opts then
		for k, v in pairs(user_opts) do
			config[k] = v
		end
	end
end

--- Get the active config table (read only!)
-- @return table: Current config values
function M.get()
	return config
end

return M
