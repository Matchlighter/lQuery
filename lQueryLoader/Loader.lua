-- 2/4/2014

local lQuerySrc = [[
local lib = {}
_G.l = lib;

local QuerySet = {}
function QuerySet:set(p, v)
	for x,i in ipairs(self._items) do
		if type(p)=="table" then
			for p2,v2 in pairs(p) do
				self:set(p2,v2)
			end
		else
			pcall(function() i[p]=v end)
		end
	end
end;
function QuerySet:get(p)
	for x,i in ipairs(self._items) do
		local w,v = pcall(function() return i[p] end)
		if w then return v end
	end
	return nil
end;
function QuerySet:each(f)
	for x,i in ipairs(self._items) do
		f(i, x)
	end
end;
function QuerySet:select()
	game.Selection:Set(self._items)
end;
function QuerySet:remove()
	while #self._items do
		pcall(function() self._items[1]:Remove() end)
		table.remove(self._items, 1)
	end
end;
function QuerySet:add(el)
	table.insert(self._items, el)
end;
function QuerySet:count()
	return #self._items
end;
function QuerySet:insert(typ, attrs)
	local ni = type(typ)=="string" and Instance.new(typ) or typ:Clone()
	lib(ni):set(attrs)
	for x,i in ipairs(self._items) do
		ni:Clone().Parent = i
	end
end;
function QuerySet:__add(oth)
	for i,v in ipairs(oth) do
		table.insert(self._items, v)
	end
end;
function QuerySet:__call() --Shortcut for :select()
	self:select()
end;

--Printing
	function QuerySet:pcount()
		print(self:count())
	end;

--Traversing
	function QuerySet:children(sel) --Get the children of each element in the set of matched elements, optionally filtered by a selector.
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
	function QuerySet:find(sel) --Get the descendants of each element in the current set of matched elements, filtered by a selector.
		local nq = {}
		self:each(function(inst)
			mergeTable(nq, execSelector(sel, inst))
		end)
		return lib(nq)
	end;
	function QuerySet:filter(sel) --Reduce the set of matched elements to those that match the selector or pass the function?s test.
		local nq={}
		self:each(function(inst)
			if (type(sel)=="function" and sel(inst)) or (type(sel)=="string" and lib.selectorMatch(sel, inst)) then
				table.insert(nq, inst)
			end
		end)
		return lib(nq)
	end;
	function QuerySet:parent(sel) --Get the parent of each element in the current set of matched elements, optionally filtered by a selector.
		local nq = {}
		self:each(function(inst)
			local c = inst.Parent
			if c~=nil and (sel==nil or lib.selectorMatch(sel, c)) then
				table.insert(nq, c)
			end
		end)
		return lib(nq)
	end
	function QuerySet:siblings(sel) --Get the siblings of each element in the set of matched elements, optionally filtered by a selector. (Does not include the original child)
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
QuerySet.__index = QuerySet;

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
local nf = "[%w_]" --Name Fields

local selectors = {
	{ --Property/value
		pat = "%["..ws.."*("..nf.."+)"..ws.."*([|%*~!%^%$]?=)"..ws.."*['\"](.*)['\"]"..ws.."*%]";
		f = function(obj, fld, opp, val)
			local suc, fstr = pcall(function() return tostring(obj[fld]) end)
			if suc then
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
			end
		end;
	};
	{ --Has/doesn't have property
		pat = "%["..ws.."*("..nf..")"..ws.."*(!?)"..ws.."*%]";
		f = function(obj, fld, opp)
			local has, ret = pcall(function() return obj[fld] end)
			return (opp=="!")==(not has)
		end;
	};
	{ --Name
		pat = "#([%$%^]?)("..nf.."+)";
		f = function(obj, opp, nm)
			if opp=="$" then
				return obj.Name:lower()==nm:lower()
			elseif opp=="^" then
				return obj.Name:upper()==nm:upper()
			end
			return obj.Name==nm
		end;
	};
	{ --className/type
		pat = "%.(%^?)([%w_]+)";
		f = function(obj, sub, cnm)
			if sub=="^" then return obj:IsA(cnm) else
			return obj.className==cnm end
		end;
	};
	{ --No Children
		pat = "<";
		f = function(obj) return #obj:GetChildren()==0 end;
	};
	{ --Everything
		pat = "%*";
		f = function() return true end;
	};
}

--Determines if a specified part of a selector matches the object
local argMatch = function (arg, obj)
	local mpatterns = {}
	for sp,sd in ipairs(selectors) do
		local pat, t = sd.pat, sd.f;
		while true do
			local a,b = string.find(arg, pat)
			if a ~= nil then
				table.insert(mpatterns, {
					f = t;
					pat = pat;
					part = string.sub(arg, a,b);
				})
				arg = string.sub(arg, 0,a-1)..string.sub(arg, b+1)
			else break
			end
		end
	end
	assert(string.len(arg)==0, "Malformed Selector! Remnant: "..arg) --Raise an error if there is a part that was not matched to anything
	for i,v in ipairs(mpatterns) do
		local targ, pat, t = v['part'], v['pat'], v['f']
		--print(pat)
		for c0,c1,c2,c3,c4,c5 in string.gmatch(targ, pat) do
			if not t(obj, c0,c1,c2,c3,c4,c5) then return false end
		end
	end
	return true
end

local escapes = {
	["\\"] = "\\";
	[" "] = "s";
}
local rescapes = {}
for a,b in pairs(escapes) do rescapes[b]=a end

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

local function selBlockMatch(section, obj)
	for i,v in ipairs(section) do
		local targ, pat, t = v['part'], v['pat'], v['f']
		for c0,c1,c2,c3,c4,c5 in string.gmatch(targ, pat) do
			if not t(obj, c0,c1,c2,c3,c4,c5) then return false end
		end
	end
	return true
end

local function extractSelectors(sel)
	local path = {{}}

	local tsel = sel
	local going = true
	while going do
		going = false
		if (tsel:sub(1,1)==" ") then
			going = true
			if #(path[#path])>0 then table.insert(path, {}) end
			tsel = tsel:sub(2)
		elseif (tsel:sub(1,1)==">") then
			going=true
			table.insert(path, ">")
			tsel = tsel:sub(2)
		else 
			for sp,sd in ipairs(selectors) do
				local pat, t = sd.pat, sd.f;
				while true do
					local a,b = string.find(tsel, '^'..pat)
					if a ~= nil then
						going = true
						table.insert(path[#path], {
							f = t;
							pat = pat;
							part = string.sub(tsel, a,b);
						})
						tsel = string.sub(tsel, 0,a-1)..string.sub(tsel, b+1)
					else break
					end
				end
			end
		end
	end
	assert(string.len(tsel)==0, "Malformed Selector! Remnant: "..tsel) --Raise an error if there is a part that was not matched to anything
	local tc = {}
	for i,v in ipairs(path) do
		if type(v)~="table" or #v>0 then
			table.insert(tc, v)
		end
	end
	return tc
end

local function testSelectors(path, obj)
	local pthEl = #path
	local cobj = obj
	while true do
		local lsel = path[pthEl]
		if lsel==">" then
			--if cobj==game or cobj.Parent==nil then break end;
			local nst = {}
			for i,v in ipairs(path) do
				if i<pthEl then
					table.insert(nst, v)
				else break end
			end
			
			if testSelectors(nst, cobj) then return true end;
			break
		elseif selBlockMatch(lsel, cobj) then
			pthEl = pthEl-1
			if pthEl == 0 then return true end
		elseif pthEl == #path then break --Last selector must match the input obj
		end
		if cobj==game or cobj.Parent==nil then break end --We've reached the top of the tree and can't go further
		cobj = cobj.Parent
	end
	return false
end

lib.selectorMatch = function (sel, obj)
	--local iter = type(sel)=="table" and ipairs(sel) or string.gmatch(sel, "[^,]")

	for ssel in string.gmatch(sel, "[^,]+") do
		local path = extractSelectors(ssel)
		if testSelectors(path, obj) then return true end
	end
	return false
end

lib.selectorMatchList = function (sel, objs)
	local ft = {}
	for ssel in string.gmatch(sel, "[^,]+") do
		local path = extractSelectors(ssel)
		for i, obj in ipairs(objs) do
			if testSelectors(path, obj) then table.insert(ft, obj) end
		end
	end
	return ft
end

local function execSelector(sel, par)
	par = par or game
	local tree = recurChilds(par)
	return lib.selectorMatchList(sel, tree)
end

local mt = {__call=function(self, inp, par)
	local qo = {}
	
	if par == nil then par = Workspace end
	if inp==nil then
		qo._items = game.Selection:Get()
	elseif type(inp) == "string" then
		qo._items = execSelector(inp, par)
	elseif type(inp) == "userdata" then
		qo._items = {inp}
	elseif type(inp) == "table" then
		qo._items = {}
		for i,v in ipairs(inp) do table.insert(qo._items, v) end
	end
	
	setmetatable(qo, QuerySet)
	return qo
end}
setmetatable(lib, mt);
]]

loadstring(lQuerySrc)()
local Pmanager = PluginManager()
local pl = Pmanager:CreatePlugin()
local TBar = pl:CreateToolbar("lQuery")
local coregui = game:GetService("CoreGui")

local installBtn = TBar:CreateButton("","Install/Update lQuery",  "script_lightning.png")
installBtn.Click:connect(function ()
	local lq = _G.l(".Script#lQuery, .LocalScript#lQuery")
	if lq:count() > 0 then
		lq:each(function (obj)
			obj.Source = lQuerySrc
			print("Updated lQuery at \"".. obj:GetFullName() .."\"")
		end)
	else
		local s = Instance.new("Script", Workspace)
		s.Name = "lQuery"
		s.Source = lQuerySrc
	end
end)