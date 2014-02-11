local lQuery = {}
_G.lQuery = lQuery
_G.l = _G.lQuery

function lQuery.toArray(tab)
	local arr = {}
	for n,v in pairs(tab) do
		table.insert(arr, v)
	end
	return arr
end

function lQuery.mergeTable(nt, ...)
	for i,v in ipairs({...}) do
		for i2,v2 in ipairs(v) do
			table.insert(nt, v2)
		end
	end
	return nt
end

--Recursively gets children along a tree
function lQuery.recurChilds(...)
	local nloop = {...}
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
function lQuery.recurParents(...)
	local nloop = {...}
	local found = {}
	while #nloop>0 do
		table.insert(found, nloop[1])
		table.insert(nloop, nloop[1].Parent)
		table.remove(nloop,1)
	end
	return found
end

local QuerySet = {}
lQuery.fn = QuerySet
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
	return self
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
	return self
end;
function QuerySet:select()
	game.Selection:Set(self._items)
	return self
end;
function QuerySet:remove(sel)
	for n,v in pairs(lQuery.selectorMatchList(sel or "*", self._items)) do
		v:Remove()
	end
	return self
end;
function QuerySet:add(el)
	return self + el
end;
function QuerySet:count()
	return #self._items
end;
function QuerySet:insert(typ, attrs)
	local ni = type(typ)=="string" and Instance.new(typ) or typ:Clone()
	lQuery(ni):set(attrs)
	for x,i in ipairs(self._items) do
		ni:Clone().Parent = i
	end
	return self
end;
function QuerySet:__add(oth)
	if type(oth)=="table" then
		if getmetatable(oth)==QuerySet then
			oth = oth._items
		end
		return lQuery(lQuery.mergeTable({}, self._items, oth))
	elseif type(oth)=="userdata" then
		return lQuery(lQuery.mergeTable({}, self._items, {oth}))
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
			lQuery.mergeTable(nq, inst:GetChildren())
		end)
		if sel ~= nil then
			nq = lQuery.selectorMatchList(sel, nq)
		end
		return lQuery(nq)
	end;
	function QuerySet:find(sel) --Get the descendants of each element in the current set of matched elements, filtered by a selector.
		local nq = {}
		self:each(function(inst)
			lQuery.mergeTable(nq, execSelector(sel, inst))
		end)
		return lQuery(nq)
	end;
	function QuerySet:filter(sel) --Reduce the set of matched elements to those that match the selector or pass the function’s test.
		local nq={}
		if type(sel)=="function" then
			self:each(function(inst)
				if sel(inst) then
					table.insert(nq, inst)
				end
			end)
		else
			nq = lQuery.selectorMatchList(sel, self._items)
		end
		return lQuery(nq)
	end;
	function QuerySet:parent(sel) --Get the parent of each element in the current set of matched elements, optionally filtered by a selector.
		local nq = {}
		self:each(function(inst)
			table.insert(nq, inst.Parent)
		end)
		if sel ~= nil then
			nq = lQuery.selectorMatchList(sel, nq)
		end
		return lQuery(nq)
	end
	function QuerySet:siblings(sel) --Get the siblings of each element in the set of matched elements, optionally filtered by a selector. (Does not include the original child)
		local nq = {}
		self:each(function(inst)
			local c = inst.Parent
			if c~=nil then
				for i,v in ipairs(c:GetChildren()) do
					if v~=inst then
						table.insert(nq, v)
					end
				end
			end
		end)
		if sel ~= nil then
			nq = lQuery.selectorMatchList(sel, nq)
		end
		return lQuery(nq)
	end;
QuerySet.__index = QuerySet;

local ws = "%s" --Whitespace
local nf = "[%w_]" --Name Fields

local selectors = {
	{ --Direct Child
		pat = "(.*)>";
		terminate = true;
		multi = true;
		f = function(objs, umobjs, subsel)
			return lQuery.selectorMatchList(subsel, objs)
		end
	};
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
	{ --Has 1+ children matching a selector
		pat = ":has(%b())";
		f = function(obj, subsel)
			local nsel = subsel:sub(2,-2)
			return #lQuery.toArray(lQuery.selectorMatchList(nsel, lQuery.recurChilds(unpack(obj:GetChildren())))) > 0
		end;
	};
	{ --Selects all elements that do NOT match the given selector
		pat = ":not(%b())";
		multi = true;
		f = function(objs, umobjs, subsel)
			local nsel = subsel:sub(2,-2)
			for n,v in pairs(lQuery.selectorMatchList(nsel, objs)) do
				objs[n] = nil
				umobjs[n] = v
			end
			return objs
		end;
	};
	{ --
		pat = ":first%-child";
		f = function(obj)
			return obj == obj.Parent:GetChildren()[1]
		end;
	};
	{ --
		pat = ":last%-child";
		f = function(obj)
			local chldrn = obj.Parent:GetChildren()
			return obj == chldrn[#chldrn]
		end;
	};
	{ --
		pat = ":only%-child";
		f = function(obj) return #obj.Parent:GetChildren()==1 end;
	};
	{ --No Children
		pat = ":empty";
		f = function(obj) return #obj:GetChildren()==0 end;
	};
	{ --Has children
		pat = ":parent";
		f = function(obj) return #obj:GetChildren()>0 end;
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
	{ --Everything
		pat = "%*";
		f = function() return true end;
	};
}

local function selBlockMatchMulti(section, left_objs)
	local mobjs = left_objs
	local umobjs = {}
	for i,v in ipairs(section) do
		if v.sel.multi then
			mobjs = v.sel.f(mobjs, umobjs, unpack(v.args))
		else
			local objs = mobjs
			mobjs = {}
			for initial, obj in pairs(objs) do
				if v.sel.f(obj, unpack(v.args)) then
					mobjs[initial] = obj
				elseif not v.sel.terminate then
					umobjs[initial] = obj
				end
			end
		end
	end
	return mobjs, umobjs
end

local function extractSelectors(sel)
	local path = {{}}
	local paths = {path}
	
	local tsel = sel
	local going = true
	while going do
		going = false
		if (tsel:sub(1,1)==" ") then
			going = true
			if #(path[#path])>0 then table.insert(path, {}) end
			tsel = tsel:sub(2)
		elseif (tsel:sub(1,1)==",") then
			going = true
			table.insert(paths, {{}})
			path = paths[#paths]
			tsel = tsel:sub(2)
		else 
			for sp,sd in ipairs(selectors) do
				while true do
					local a,b = string.find(tsel, '^'..sd.pat)
					if a ~= nil then
						going = true
						local part = string.sub(tsel, a,b);
						table.insert(path[#path], {
							sel = sd;
							args = {part:match(sd.pat)};
						})
						tsel = string.sub(tsel, 0,a-1)..string.sub(tsel, b+1)
					else break
					end
				end
			end
		end
	end
	assert(string.len(tsel)==0, "Malformed Selector! Remnant: "..tsel) --Raise an error if there is a part that was not matched to anything
	local cpaths = {}
	for n, pth in ipairs(paths) do
		local tc = {}
		for i,v in ipairs(pth) do
			if type(v)~="table" or #v>0 then
				table.insert(tc, v)
			end
		end
		if #tc > 0 then
			table.insert(cpaths, tc)
		end
	end
	return cpaths
end

local function testSelectorsMulti(paths, objs)
	local fmatches = {}
	for i, path in ipairs(paths) do
		local pthEl = #path
		local next_iter = {}
		for i,v in pairs(objs) do
			if type(i) == "number" then i = v end
			next_iter[i] = v
		end
		while true do
			local lsel = path[pthEl]
			local c_iter = next_iter
			next_iter = {}
			local nmc = 0
			
			local matches, non_matches = {}, {}
			repeat --Eliminate everything we can
				matches, non_matches = selBlockMatchMulti(lsel, c_iter)
			
				for initial, cobj in pairs(matches) do --Capture items that were successfully matched and queue them for the next selector
					if not (cobj==game or cobj.Parent==nil) then --We've reached the top of the tree and can't go further
						next_iter[initial] = cobj.Parent
					end
				end
				
				c_iter = {}
				nmc = 0
				for initial, cobj in pairs(non_matches) do
					if (not (cobj==game or cobj.Parent==nil)) and pthEl ~= #path then --We've reached the top of the tree and can't go further --Last selector must match the input obj
						c_iter[initial] = cobj.Parent
						nmc = nmc+1
					end
				end
			until nmc == 0
			
			pthEl = pthEl-1
			if pthEl == 0 then --We're done here.
				for initial, cobj in pairs(next_iter) do
					fmatches[initial] = initial
				end
				break
			end
		end
	end
	return fmatches
end

lQuery.selectorMatch = function (sel, obj)
	return #lQuery.selectorMatchList(paths, {obj})>0
end

lQuery.selectorMatchList = function (sel, objs)
	local ft = {}
	local paths = extractSelectors(sel)
	return testSelectorsMulti(paths, objs)
end

local function execSelector(sel, par)
	local tree = lQuery.recurChilds(par)
	local tbl = lQuery.selectorMatchList(sel, tree)
	return lQuery.toArray(tbl)
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
		for i,v in pairs(inp) do table.insert(qo._items, v) end
	end
	
	setmetatable(qo, QuerySet)
	return qo
end}
setmetatable(lQuery, mt);
return lQuery
