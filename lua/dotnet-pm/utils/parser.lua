--- dotnet-pm.utils.parser
-- Cross-platform .sln and .csproj parsing utilities for dotnet-pm.nvim.

local M = {}

--- Parse a .sln file to extract C# project entries.
-- @param sln_path string: Path to the .sln file
-- @return table: List of tables { name = <project name>, path = <relative csproj path> }
function M.parse_sln_projects(sln_path)
	local projects = {}
	local file = io.open(sln_path, "r")
	if not file then
		vim.notify("Failed to open solution file: " .. sln_path, vim.log.levels.ERROR)
		return projects
	end
	for line in file:lines() do
		-- Match project entry lines in .sln (hyphen or backslash tolerant)
		local prj_name, prj_path = line:match('Project%s*%([^%)]+%)%s*=%s*"([^"]+)"%s*,%s*"([^"]+%.csproj)"')
		if prj_name and prj_path then
			-- Normalize path separators for cross-platform use
			prj_path = prj_path:gsub("\\", "/")
			table.insert(projects, { name = prj_name, path = prj_path })
		end
	end
	file:close()
	return projects
end
--- Recursively scans a directory for files, skipping common unwanted folders and filtering by extension.
-- @param base_dir string: Directory to scan
-- @param exclude_exts table|nil: Set of excluded extensions ([".dll"]=true, ...)
-- @return table: Flat paths of files (relative to base_dir) that aren't filtered out
local function scan_files(base_dir, parent, results, exclude_exts)
	parent = parent or ""
	results = results or {}
	exclude_exts = exclude_exts or {}
	local uv = vim.loop

	local function scandir(dir, rel_prefix)
		local handle = uv.fs_scandir(dir)
		while handle do
			local name, typ = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			local rel = rel_prefix ~= "" and (rel_prefix .. "/" .. name) or name
			local full = dir .. "/" .. name
			if typ == "file" then
				local ext = name:match("^.+(%.[a-zA-Z0-9]+)$") or ""
				if not exclude_exts[ext] then
					table.insert(results, rel)
				end
			elseif typ == "directory" and name ~= "bin" and name ~= "obj" and name ~= ".git" then
				scandir(full, rel)
			end
		end
	end
	scandir(base_dir, parent)
	return results
end

--- Parse a .csproj file and return all relevant files (not just .cs).
-- Supported filters via opts.exclude_exts (set of extensions to exclude)
-- @param csproj_path string: Path to the .csproj file
-- @param opts table|nil: Optional { exclude_exts = table of extensions }
-- @return table: file list (relative to project dir)
function M.parse_csproj_files(csproj_path, opts)
	opts = opts or {}
	local files = {}
	local has_explicit = false
	local explicit_exts = opts.explicit_exts or { [".cs"] = true }
	local exclude_exts = opts.exclude_exts or {}

	-- Parse explicit entries (legacy)
	local csproj_file = io.open(csproj_path, "r")
	if csproj_file then
		for line in csproj_file:lines() do
			local src = line:match('Include="([^"]+)"')
			if src then
				src = src:gsub("\\", "/")
				local ext = src:match("^.+(%.[a-zA-Z0-9]+)$") or ""
				if explicit_exts[ext] and not exclude_exts[ext] then
					table.insert(files, src)
					has_explicit = true
				end
			end
		end
		csproj_file:close()
	end
	if has_explicit then
		return files
	end
	-- Otherwise: scan directory for all relevant files by default
	local base_dir = csproj_path:match("(.+)[\\/][^\\/]+$")
	files = scan_files(base_dir, nil, nil, exclude_exts)
	return files
end

return M
