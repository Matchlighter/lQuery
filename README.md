lQuery
======

jQuery-inspired object selector for rbxLua

Use l("<selector>") to create a lQuery object.
Available selectors are: (Variations noted in parentheses ())
#Name
.(^)className (^ Use :IsA()instead of direct className comparison)
[hasProperty(!)]
[property(|*~!^$)="value"]
