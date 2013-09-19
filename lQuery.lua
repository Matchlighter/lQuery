local lib = {}
_G.l = lib;

local cls = {}
--setmetatable(cls, {})
function cls:set(p, v)
	for x,i in ipairs(self._items) do
		pcall(function() i[p]=v end)
	end
end;
function cls:get(p)
	for x,i in ipairs(self._items) do
		local w,v = pcall(function() return i[p] end)
		if w then return v end
	end
	return nil
end;
function cls:each(f)
	for x,i in ipairs(self._items) do
		f(i, x)
	end
end;
function cls:add(el)
	table.insert(self._items, el)
end;
function cls:__add(oth)1
	for i,v in ipairs(oth) do
		table.insert(self._items, v)
	end
end;

--Traversing
	function cls:children(sel) --Get the children of each element in the set of matched elements, optionally filtered by a selector.
		local nq = {}
		self:each(function(inst)
			for i,c in ipairs(inst:GetChildren()) do
				if sel==nil or lib.selectorMatch(sel, c) then
					table.insert(nq, c)
				end
			end
		end)
		return lib(nq)
	end;
	function cls:find(sel) --Get the descendants of each element in the current set of matched elements, filtered by a selector.
		local nq = {}
		self:each(function(inst)
			mergeTable(nq, execSelector(sel, inst))
		end)
		return lib(nq)
	end;
	function cls:filter(sel) --Reduce the set of matched elements to those that match the selector or pass the function’s test.
		local nq={}
		self:each(function(inst)
			if (type(sel)=="function" and sel(inst)) or (type(sel)=="string" and lib.selectorMatch(sel, inst)) then
				table.insert(nq, inst)
			end
		end)
		return lib(nq)
	end;
	function cls:parent(sel) --Get the parent of each element in the current set of matched elements, optionally filtered by a selector.
		local nq = {}
		self:each(function(inst)
			local c = inst.Parent
			if c~=nil and (sel==nil or lib.selectorMatch(sel, c) then
				table.insert(nq, c)
			end
		end)
		return lib(nq)
	end
	function cls:siblings(sel) --Get the siblings of each element in the set of matched elements, optionally filtered by a selector. (Does not include the original child)
		local nq = {}
		self:each(function(inst)
			local c = inst.Parent
			if c~=nil then
				for i,v in ipairs(c:GetChildren()) do
					if v~=inst and (sel==nil or lib.selectorMatch(sel, v)) then
						table.insert(nq, v)
					end
				end
			end
		end)
		return lib(nq)
	end;
cls.__index = cls;

local mt = {__call=function(inp)
	local qo = {}
	
	if type(inp) == "string" then
		qo._items = execSelector(inp)
	elseif type(inp) == "userdata" then
		qo._items = {inp}
	elseif type(inp) == "table" then
		qo._items = {}
		for i,v in ipairs(inp) do table.insert(qo._items, v) end
	end
	
	setmetatable(qo, cls)
	return qo
end}
table.setmetatable(lib, mt);

local function mergeTable(t1, t2)
	for i,v in ipairs(t2) do
		table.insert(t1, v)
	end
	return t1
end

--Recursively gets children along a tree
local function recurChilds(par)
	local nloop = {par}
	local found = {}
	while #nloop>0 do
		table.insert(found, nloop[1])
		for i,v in ipairs(nloop[1]:GetChildren()) do
			table.insert(nloop, v)
		end
		table.remove(nloop,1)
	end
	return found
end

--Recursively gets parents along a tree
local function recurParents(chld)
	local nloop = {chld}
	local found = {}
	while #nloop>0 do
		table.insert(found, nloop[1])
		table.insert(nloop, nloop[1].Parent)
		table.remove(nloop,1)
	end
	return found
end

local ws = "%s" --Whitespace
local nf = "[%w_ ]" --Name Fields

local selectors = {
	["#([%$%^]?)("..nf.."+)"] = function(obj, opp, nm) --Name
		if opp=="$" then
			return obj.name:lower()==nm:lower()
		elseif opp=="^" then
			return obj.name:upper()==nm:upper()
		end
		return obj.name==nm
	end;
	["%.(%^?)([%w_]+)"] = function(obj, sub, cnm) --className/type
		if sub=="^" then return obj:IsA(cnm) else
		return obj.className==cnm end
	end;
	["%["..ws.."*("..nf.."+)"..ws.."*([|%*~!%^]?=)"..ws.."*'(.*)'"..ws.."*%]"] = function(obj, fld, opp, val) --Property/value
		local fstr = tostring(obj[fld])
		if opp=="|=" then
			return fstr:sub(1, val:len()+1)==val.."-"
		elseif opp=="*=" then
			return fstr:match(val)~=nil
		elseif opp=="~=" then
			return string.match(" "..fstr.." ", "%s"..val.."%s")~=nil
		elseif opp=="^=" then
			return fstr:match("^"..val)~=nil
		elseif opp=="$=" then
			return fstr:match(val.."$")~=nil
		elseif opp=="!=" then
			return fstr~=val
		elseif opp=="=" then
			return fstr == val;
		end
	end;
	["%["..ws.."*("..nf..")"..ws.."*(!?)"..ws.."*%]"] = function(obj, fld, opp) --Property not nil/nil
		if opp=="!" then return obj[fld]==nil end
		return obj[fld] != nil
	end;
	["%*"] = function() return true;
}

--Determines if a specified part of a selector matches the object
local argMatch = function (arg, obj)
	for pat, t in pairs(selectors) do
		for c1, c2, c3, c4, c5 in string.gmatch(arg, pat) do
			if not t(obj, c1, c2, c3, c4, c5) then return false end
		end
	end
	return true
end

local escapes = {
	["\\"] = "\\";
	[" "] = "s";
}
local rescapes = {}
for a,b in escapes do reascapes[b]=a end

local function escape(str)
	for p,e in pairs(escapes) do
		str=str:gsub(p,"\\"..e)
	end
	return str
end

local function unescape(str)
	return str:gsub("\\(.)", function(c)
		for e,p in pairs(rescapes) do
			if e==c then return p end
		end
	end)
end

lib.selectorMatch = function (sel, obj)
	--local iter = type(sel)=="table" and ipairs(sel) or string.gmatch(sel, "[^,]")
	for ssel in string.gmatch(sel, "[^,]") do
		local path = {}
		ssel = ssel:gsub("%b[]", function(m) return m:gsub("\'\'", escape) end) --Escape quoted spaces
		
		for prm in string.gmatch(ssel, "[^ ]+") do table.insert(path, unescape(prm)) end
		
		local pthEl = #path
		local cobj = obj
		while true do
			local lsel = path[pthEl]
			if lsel==">" then
				if cobj==game or cobj.Parent==nil then break;
				if lib.selectorMatch(table.concat(path, " ", 1, pthEl-1), cobj.Parent) then return true;
				break
			elseif argMatch(lsel, cobj) then
				pthEl = pthEl-1
				if pthEl == 0 then return true end
			elseif pthEl == #path then break --Last selector must match the input obj
			elseif cobj==game or cobj.Parent==nil then break --We've reached the top of the tree and can't go further
			end
			cobj = cobj.Parent
		end
	end
	return false
end

local function execSelector(sel, par)
	par = par || game
	local tree = recurChilds(par)
	local matches = {}
	for i,v in ipairs(tree) do
		if lib.selectorMatch(sel, v) then table.insert(matches, v) end
	end
	return matches
end

