local argparse = require "argparse"

local parser = argparse(arg[0], "A lua interpreter")
parser:argument("script", "script to execute")

local args = parser:parse()

local lala="asdfgh"
print (lala:sub(1,1))

print("Executing "..args.script)
assert(loadfile(args.script))()
print("Done")