# MyGemini_plugin_for_nvim
asking Gemini through API_KEY inside neovim

# install
copy the .lua file to your neovim init file and add the followin to init.lua
```
local Gemini = require('Gemini')
Gemini.setup({
  api_key = "your way to show api_key"
})
```

# How to use
using visual mode in neovim with 'v'<br />
and select the code or text you want to pass to Gemini <br />
press ':' and type 'GeminiAskCode' or type 'Gemin....' and use tab.<br />

also you can concat what ever you want to prompt to Gemini after what you selected
for example:
inside "" is all pass to Gemini
"
```
the code I selected
```
'the text you want to add'
"
achieve above you can use <br />
:GeminiAskCode 'the text you want to add'
