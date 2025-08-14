local M = {}
local folder_icon = " " -- unicode folder

local ext_icons = {
	[".json"] = " ", -- nf-seti-json
	[".cs"] = " ",
	[".xml"] = " ", -- nf-seti-xml
	[".resx"] = " ",
	[".config"] = " ",
}

local file_icon = "e"

function M.pick_icon(fname)
	local ext = fname:match("%.([a-zA-Z0-9]+)$")
	return ext and ext_icons["." .. ext] or file_icon
end

function M.get_folder_icon()
	return folder_icon
end

return M
