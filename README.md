lQuery
======

jQuery-inspired object selector for rbxLua

Selectors
==
Use l("<selector>") to create a lQuery object.  
Available selectors are: (Variations noted in parentheses ())
- #(^$)Name
  - ^ Starts with
  - $ Ends with
- .(^)className
  - ^ Use :IsA() instead of direct className comparison
- [hasProperty(!)]
  - ! Does not have property
- [property(|*~!^$)="value"]
  - | Attribute contains prefix ("value-")
  - * Attribute contains
  - ~ Attribute contains word (" value ")
  - ^ Attribute starts with
  - $ Attribute ends with
  - ! Attribute is not
- > Immediate child
- :not(selector)
- :first-child
- :last-child
- :has(selector)
- :only-child
- :empty
- :parent - Any object that has children

Usage
==
- Grouped selectors apply to one object. e.g. "#Name.Part" will match a Part name "Name"  
- Space separated selectors will match a tree. e.g. "#Name .Part" will match a Part with an acestor named "Name"  
- Comma separated selectors will be treated as individual selectors with an or operation. e.g. "#Name, .Part" will match anything named "Name" or any Part.  

Any combination of the above will work. e.g. "#Obj.Part .PointLight, .Model" will match any Models, or any PointLights with a Part named "Obj" as an ancestor.
