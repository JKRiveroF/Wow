-- 9.7.6: shared catalog, data filters and context, built only on demand.
local _,GL=...
local L=GL.L or function(s)return s end
local function call(f,...) if type(f)~="function" then return end; local ok,a,b,c=pcall(f,...); if ok then return a,b,c end end
local function visible(v)
 if type(issecretvalue)=="function" then local ok,secret=pcall(issecretvalue,v); if not ok or secret then return nil end end
 return v
end
local function norm(s)
 s=visible(s)
 if GL.NormalizarBusqueda97 then return GL.NormalizarBusqueda97(s) end
 s=tostring(s or ""):lower(); for a,b in pairs({["á"]="a",["é"]="e",["í"]="i",["ó"]="o",["ú"]="u",["ñ"]="n",["Á"]="a",["É"]="e",["Í"]="i",["Ó"]="o",["Ú"]="u",["Ñ"]="n"}) do s=s:gsub(a,b) end; return s
end
local function score(n,q)
 if n==q then return 1 elseif n:find(q,1,true)==1 then return 2 elseif n:find(q,1,true) then return 3 end
end
local function mejor(a,b) if b and (not a or b<a) then return b end; return a end
local index,whCache,facCache,localeCache,revisionCache
local nombresPersistentes = {}
function GL.Catalogo976(q,limit,tipo)
 q=norm(q):match("^%s*(.-)%s*$"); local id=tonumber(q); limit=tonumber(visible(limit)) or 40; if limit~=limit then limit=40 end; limit=math.floor(math.min(100,math.max(1,limit))); if #q<3 and not id then return {} end
 local wh=GL.WH or {}; local fac=visible(call(UnitFactionGroup,"player")); local locale=tostring(visible(call(GetLocale)) or "")..":"..tostring(GL.ingles)
 if not index or whCache~=wh or facCache~=fac or localeCache~=locale or revisionCache~=GL.RevisionCatalogo976 then
  index={}; nombresPersistentes={}; whCache,facCache,localeCache,revisionCache=wh,fac,locale,GL.RevisionCatalogo976
  local seen={}
  local function add(kind,name,n,context,action,objects,extra)
   if not name and not n then return end
   local key=kind..":"..tostring(n or name)..":"..tostring(context or ""); if seen[key] then return end; seen[key]=true
   local label=name and L(name) or (L"Objeto".." #"..tostring(n)); local d=L(kind)..(context and (" · "..L(context)) or "")
   local e={tipo=kind,n=label,id=n,d=d,search=norm(label.." "..tostring(name or "").." "..d),modo=action,objetos=objects}; for k,v in pairs(extra or {}) do e[k]=v end; e.nombreNormalizado=norm(e.n); e.aliasNormalizado=norm(e.alias or "")
   local ingles=kind=="Misión" and n and GL.misionesIngles and GL.misionesIngles[n] or nil
   if not ingles and name then ingles=call(GL.EnIngles,name) end
   e.inglesNormalizado=norm(type(ingles)=="string" and ingles or "")
   index[#index+1]=e
  end
  for _,b in ipairs((GL.D94 and GL.D94.bandas) or {}) do
   add("Banda",b.n,nil,nil,"mazmorras",nil,{banda=b.clave or b.n,alias=b.ing})
  end
  local zones={}; for z in pairs(wh.jefes or {}) do zones[#zones+1]=z end; table.sort(zones)
  for _,z in ipairs(zones) do for _,b in ipairs(GL.JefesVisibles976(z)) do
   add("Jefe",b.n,b.npc,z,nil,b.botin or {},{zonaJefe=z,jefe=b.n})
   for _,o in ipairs(b.botin or {}) do add("Botín",o.n,o.id,z.." / "..b.n,nil,{o}) end
  end end
  for _,p in ipairs(wh.profesiones or {}) do
   add("Profesión",p.n,p.skill,nil,"oficios",nil,{skill=p.skill})
   for _,m in ipairs(call(GL.ModalidadesProfesion975,p.skill) or {"referencia"}) do if m~="ruta" then
    local plan=call(GL.PlanProfesion975,p.skill,m) or p
    for _,t in ipairs(plan.tramos or {}) do add("Receta",t.r,t.sp,p.n,"oficios",nil,{skill=p.skill}); for _,v in ipairs(t.mat or {}) do add("Material",v[3],v[1],p.n,nil,{{id=v[1],n=v[3]}}) end end
   end end
  end
  for _,d in ipairs(call(GL.DatosMazmorras) or {}) do for _,m in ipairs(d.misiones or {}) do add("Misión",m.n,m.q,d.n,"mazmorras",nil,{m=d}) end end
  for _,k in ipairs(fac=="Horde" and {"opcionalesH","opcionalesNuevasH"} or fac=="Alliance" and {"opcionales","opcionalesNuevas"} or {}) do for n,m in pairs(wh[k] or {}) do if type(n)=="number" and type(m)=="table" and type(m.n)=="string" then local lines={L(m.n).." (#"..n..")",L"Consulta de misión; disponibilidad no confirmada."}; for _,w in ipairs(m.wp or {}) do lines[#lines+1]=L(w.n or "").." — "..L(w.z or "").." "..tostring(w.x or "?")..", "..tostring(w.y or "?") end; add("Misión",m.n,n,nil,nil,nil,{informe=table.concat(lines,"\n")}) end end end
  table.sort(index,function(a,b) if a.d~=b.d then return a.d<b.d end; if a.n~=b.n then return a.n<b.n end; return (tonumber(a.id) or 0)<(tonumber(b.id) or 0) end)
 end
 local groups={{},{},{},{}}; local nombres={}; for _,e in ipairs(index) do
  if not tipo or tipo==e.tipo then
  local cachedName
  if not id and e.id and e.objetos and #e.objetos==1 and e.objetos[1].id==e.id then
   local dato=nombresPersistentes[e.id]
   if dato==nil then dato=nombres[e.id] end
   if dato==nil then
    local n
    local disponible=visible(call(C_Item and C_Item.IsItemDataCachedByID,e.id))
    -- Solo una respuesta negativa explícita debe impedir la consulta.
    -- Una API ausente o fallida permite recurrir a GetItemInfo.
    if disponible~=false then
     n=visible(call(C_Item and C_Item.GetItemInfo or GetItemInfo,e.id))
     if (type(n)~="string" or n=="") and C_Item and C_Item.GetItemInfo~=GetItemInfo then n=visible(call(GetItemInfo,e.id)) end
    end
    dato=type(n)=="string" and n~="" and {n=n,normal=norm(n)} or false
    if dato then nombresPersistentes[e.id]=dato end
   end
   nombres[e.id]=dato
   if dato then cachedName=dato.n end
  end
  local rank
  if id then if tonumber(e.id)==id then rank=1 end
  else
   rank=mejor(score(e.nombreNormalizado,q),score(e.aliasNormalizado,q))
   rank=mejor(rank,score(e.inglesNormalizado,q))
   if cachedName then rank=mejor(rank,score(nombres[e.id].normal,q)) end
   if not rank and e.search:find(q,1,true) then rank=4 end
  end
  if rank and #groups[rank]<limit then local v=e; if cachedName then v={}; for k,x in pairs(e) do v[k]=x end; v.n=cachedName end; groups[rank][#groups[rank]+1]=v end
  end
 end
 local out={}; for _,g in ipairs(groups) do for _,e in ipairs(g) do if #out>=limit then return out end; out[#out+1]=e end end
 return out
end
local function numeroContexto(v)
 v=visible(v)
 if type(v)=="number" and v==v and v>=0 and v<math.huge then return v end
end
function GL.ContextoExtra976()
 local out={}; for _,p in ipairs(GL.WH and GL.WH.profesiones or {}) do
  local n,cap=call(GL.NivelProfesion,{skill=p.skill,nombre=L(p.n)})
  n,cap=numeroContexto(n),numeroContexto(cap)
  if n and n>0 and cap and cap>0 and n<=cap and cap<300 and n>=cap-5 then out[#out+1]=L"Próximo rango de profesión: "..L(p.n).." "..n.."/"..cap end
 end
 local db=visible(GuiaAventureroDB); local repair=numeroContexto(type(db)=="table" and db.ultimaReparacion); local gold=numeroContexto(call(GetMoney))
 if repair and gold and repair>gold then out[#out+1]=L"Oro insuficiente para el último coste de reparación registrado." end
 local gear=call(GL.MejorEquipoANivel976)
 for i=1,math.min(3,type(gear)=="table" and #gear or 0) do local g=visible(gear[i]); if type(g)=="table" then local enlace,jefe=visible(g.enlace),visible(g.jefe); if type(enlace)=="string" and enlace~="" then out[#out+1]=L"Posible mejora de equipo: "..enlace.." — "..tostring(jefe or "") end end end
 return out
end
