--- dotnet-pm.utils.explorer
-- Solution Explorer display logic for dotnet-pm.nvim.

local parser = require("dotnet-pm.utils.parser")
local icons = require("dotnet-pm.utils.icons")
local M = {}

local folder_icon = " " -- unicode folder
local file_icon = " " -- unicode file

-- Converts flat paths to a nested tree table
local function files_to_tree(paths)
	local tree = {}
	for _, path in ipairs(paths) do
		local parts = {}
		for part in string.gmatch(path, "[^/]+") do
			table.insert(parts, part)
		end
		local node = tree
		for i = 1, #parts do
			local key = parts[i]
			if i == #parts then
				node[key] = true -- file
			else
				node[key] = node[key] or {}
				node = node[key]
			end
		end
	end
	return tree
end

-- Recursively render the tree, pretty-printing folders/files
-- Recursively render tree with ASCII connectors
local function render_tree(node, indent, lines)
	indent = indent or ""
	lines = lines or {}

	local folders, files = {}, {}
	for k, v in pairs(node) do
		if type(v) == "table" then
			table.insert(folders, k)
		else
			table.insert(files, k)
		end
	end
	table.sort(folders)
	table.sort(files)

	-- Top level: all children use └──
	if indent == "      " then
		for _, name in ipairs(folders) do
			local child = node[name]
			table.insert(lines, indent .. "└──  " .. folder_icon .. name)
			render_tree(child, indent .. "    ", lines)
		end
		for _, name in ipairs(files) do
			table.insert(lines, indent .. "└──  " .. icons.pick_icon(name) .. name)
		end
	else
		-- Subfolders: use ├── except last, which gets └──
		local keys, types = {}, {}
		for _, name in ipairs(folders) do
			table.insert(keys, name)
			table.insert(types, "folder")
		end
		for _, name in ipairs(files) do
			table.insert(keys, name)
			table.insert(types, "file")
		end
		for i, name in ipairs(keys) do
			local is_last = i == #keys
			local prefix = is_last and "└──  " or "├──  "
			if types[i] == "folder" then
				local child = node[name]
				local icon = require("dotnet-pm.utils.icons")
				table.insert(lines, indent .. prefix .. icon.pick_icon(name) .. name)
				render_tree(child, indent .. (is_last and "    " or "│   "), lines)
			else
				local icon = require("dotnet-pm.utils.icons")
				table.insert(lines, indent .. prefix .. icon.pick_icon(name) .. name)
			end
		end
	end

	return lines
end
--- Open the Solution Explorer sidebar and populate with project/file info.
-- @param sln_path string: path to the .sln file
function M.open(sln_path)
	-- Open in a vertical split
	vim.cmd("vsplit")
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)

	local lines = {
		"dotnet-pm.nvim Solution Explorer",
		"------------------------------",
	}

	if not sln_path or sln_path == "" then
		table.insert(lines, "No .sln path provided!")
	else
		table.insert(lines, "Solution: " .. sln_path)
		table.insert(lines, "")
		local projects = parser.parse_sln_projects(sln_path)
		if #projects == 0 then
			table.insert(lines, "No projects found in solution.")
		else
			table.insert(lines, "Projects:")
			-- Get solution directory (for resolving project paths)
			local sln_dir = sln_path:match("(.+)[\\/][^\\/]+$")
			for _, proj in ipairs(projects) do
				-- Display project line
				table.insert(lines, "  • " .. proj.name .. " (" .. proj.path .. ")")

				-- Resolve project path (absolute if already so, else relative to .sln)
				local proj_full = proj.path
				if not proj_full:match("^%a:[/\\]") and not proj_full:match("^/") then
					proj_full = sln_dir .. "/" .. proj.path
				end

				-- List .cs files for this project using cross-platform parser
				local config = require("dotnet-pm.utils.config").get()
				local files = parser.parse_csproj_files(proj_full, { exclude_exts = config.exclude_exts })
				local file_tree = files_to_tree(files)
				local file_lines = render_tree(file_tree, "      ")
				for _, line in ipairs(file_lines) do
					table.insert(lines, line)
				end
			end
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

return M
