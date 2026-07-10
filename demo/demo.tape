# Run with: vhs demo/demo.tape
# Install:  yay -S vhs   (or from https://github.com/charmbracelet/vhs)

Output demo/demo.gif

Set FontSize 15
Set Width 800
Set Height 420
Set Theme "Dracula"
Set Shell "bash"
Set FontFamily "JetBrains Mono"

Hide
Type "cd /path/to/Lazarus"
Enter
Show

Sleep 500ms

Type "cat demo/Demo.class.laz"
Sleep 300ms
Enter
Sleep 2s

Type "lua bin/lazarusc.lua demo/Demo.class.laz --pkg-path ."
Sleep 300ms
Enter
Sleep 3s

Type "lua Demo.lua"
Sleep 300ms
Enter
Sleep 2s
