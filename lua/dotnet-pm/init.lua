local config = require("dotnet-pm.utils.config")
local explorer = require("dotnet-pm.utils.explorer")

--- Setup function (for user)
local function setup(opts)
	config.setup(opts)
end

vim.api.nvim_create_user_command("DotnetSolutionExplorer", function(params)
	explorer.open(params.args)
end, {
	nargs = "?",
	desc = "Open the .NET Solution Explorer for a .sln file",
})

return {
	setup = setup,
}
