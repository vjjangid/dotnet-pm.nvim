--- dotnet-pm.utils.explorer
-- Solution Explorer display logic for dotnet-pm.nvim.

local parser = require("dotnet-pm.utils.parser")
local icons = require("dotnet-pm.ui.icons")
local paths = require("dotnet-pm.utils.paths")

local M = {}

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
			table.insert(lines, indent .. "└──  " .. icons.get_folder_icon() .. name)
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
				table.insert(lines, indent .. prefix .. icons.pick_icon(name) .. name)
				render_tree(child, indent .. (is_last and "    " or "│   "), lines)
			else
				table.insert(lines, indent .. prefix .. icons.pick_icon(name) .. name)
			end
		end
	end

	return lines
end
--- Open the Solution Explorer sidebar and populate with project/file info.
-- @param sln_path string: path to the .sln file
function M.open(sln_path)
	-- Open in a vertical split

	local cfg = require("dotnet-pm.utils.config").get()
	local width = cfg.explorer_width or 40
	vim.cmd("botright vsplit")
	vim.cmd("vertical resize " .. width)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_buf_set_option(buf, "wrap", false)

	local lines = {
		"dotnet-pm.nvim Solution Explorer",
		"------------------------------",
	}

	local line_to_file = {} -- BUFFER line number => absolute file path

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
			local sln_dir = sln_path:match("(.+)[\\/][^\\/]+$")

			for _, proj in ipairs(projects) do
				table.insert(lines, "  • " .. proj.name .. " (" .. proj.path .. ")")
				local project_absolute_path = proj.path
				if not project_absolute_path:match("^%a:[/\\]") and not project_absolute_path:match("^/") then
					project_absolute_path = sln_dir .. "/" .. proj.path
				end

				local config = require("dotnet-pm.utils.config").get()
				local files = parser.parse_csproj_files(project_absolute_path, { exclude_exts = config.exclude_exts }) -- {rel => abs}

				-- For each file found in this project:
				for rel, abs in pairs(files) do
					local line = "      └─ " .. rel -- you can make this tree-like as needed!
					table.insert(lines, line)
					line_to_file[#lines] = abs -- record the buffer line to abs path mapping
				end
			end
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_var(buf, "dotnet_pm_line_to_file", line_to_file)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		"<cmd>lua require('dotnet-pm.utils.explorer').open_file_under_cursor()<CR>",
		{ noremap = true, silent = true }
	)
end

function M.open_file_under_cursor()
	local buf = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local ok, line_to_file = pcall(vim.api.nvim_buf_get_var, buf, "dotnet_pm_line_to_file")
	if ok and line_to_file[line] then
		vim.cmd("vsplit " .. vim.fn.fnameescape(line_to_file[line]))
	else
		vim.notify("Not a file or file not found.", vim.log.levels.WARN)
	end
end
return M
