Output demo/demo.gif

Set FontSize 14
Set Width 1000
Set Height 500
Set Theme "Dracula"
Set Shell "bash"

Hide
Type "cd /home/nightmare/Github/lazarus-lang/Laze"
Enter
Sleep 300ms
Show

Ctrl+L
Sleep 400ms

Type "cat demo/Demo.class.laz"
Sleep 200ms
Enter
Sleep 2500ms

Type "lua bin/lazec.lua demo/Demo.class.laz --pkg-path ."
Sleep 200ms
Enter
Sleep 3s

Type "lua Demo.lua"
Sleep 200ms
Enter
Sleep 2500ms
