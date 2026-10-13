assert(vim.fn.has("nvim-0.12") == 1 and vim.pack and vim.pack.add, "Neovim 0.12+ with vim.pack is required")
if arg[1] then
  for _, file in ipairs(vim.fn.globpath(arg[1] .. "/nvim", "**/*.lua", false, true)) do
    assert(loadfile(file))
  end
end
print("Neovim " .. tostring(vim.version()) .. " is compatible")
