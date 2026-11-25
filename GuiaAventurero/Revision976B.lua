-- 9.7.6: supplementary read-only tools; no route changes, no XP or keyboard bindings.
local _, GL = ...
if type(GL)~='table' then return end
local L=GL.L or function(s)return s end
local function call(fn,...)
 if type(fn)~='function' then return nil end
 local ok,a,b,c,d,e=pcall(fn,...); if ok then return a,b,c,d,e end
end
local function visible(v)
 if type(issecretvalue)=="function" then local ok,secret=pcall(issecretvalue,v); if not ok or secret then return nil end end
 return v
end
local function cantidad(v)
 v=visible(v); if type(v)=="number" and v==v and v>=0 and v<math.huge and v%1==0 then return v end
end
local function show(t)
 local s=table.concat(t,'\n'); if GL.MostrarInforme then GL.MostrarInforme(s) elseif GL.Mensaje then GL.Mensaje(s) end; return s
end
-- Read-only migration of our own preferences: preserve progress and unrelated options.
function GL.Revision976Preferencias(db)
 if type(db)~='table' then return nil end
 if type(db.precios976)~='table' then db.precios976={} end
 if type(db.planProfesiones975)~='table' then db.planProfesiones975={} end
 if type(db.questie976)~='boolean' then db.questie976=false end
 return db
end
if GL.alIniciar then table.insert(GL.alIniciar,function() GL.Revision976Preferencias(GuiaAventureroDB) end) end
-- Combine material requirements after internal reuse in each plan, discount shared inventory once.
-- Cross-profession output is not guessed; the result can overestimate, but won't count a bag stack twice.
function GL.ComprasJuntas976(planes, contar)
 local sum,missing,unknown={},0,false
 for _,p in ipairs(planes or {}) do
  local lista,n=GL.ComprasProfesion975(p.prof,p.nivel,function()return 0 end)
  missing=missing+(n or 0)
  for _,m in ipairs(lista or {}) do
   local a=sum[m.id] or {id=m.id,nombre=m.nombre,necesito=0}; sum[m.id]=a; a.necesito=a.necesito+m.falta
  end
 end
 local out={}; for id,a in pairs(sum) do
  local n=cantidad(call(contar,id)); if n==nil then unknown=true; n=0 end
  a.tengo=math.max(0,n); a.falta=math.max(0,a.necesito-a.tengo); out[#out+1]=a
 end
 table.sort(out,function(a,b)return a.id<b.id end); return out,missing,unknown
end
local function inventario(id)
 if type(GL.InventarioProfesion975)=="function" then return cantidad(call(GL.InventarioProfesion975,id)) end
 local moderno=C_Item and C_Item.GetItemCount
 local n=cantidad(call(moderno,id,true)); if n~=nil then return n end
 if GetItemCount~=moderno then return cantidad(call(GetItemCount,id,true)) end
end
local function planes()
 local a={}; for _,p in ipairs(GL.RUTA and GL.RUTA.profesiones or {}) do
  local n=call(GL.NivelProfesion,p); if type(n)=='number' and n>0 and n<300 and p.skill then a[#a+1]={prof=p,nivel=n} end
 end; return a
end
-- Read only currently available legacy browse results, no scan or buying. Exact item IDs, buyout/stack.
function GL.PrecioSubastaVisible976(id)
 if not (AuctionFrame and AuctionFrame.IsShown and AuctionFrame:IsShown() and GetNumAuctionItems and GetAuctionItemInfo and GetAuctionItemLink) then return nil,0 end
 id=cantidad(id); if not id or id==0 then return nil,0 end
 local n=cantidad(call(GetNumAuctionItems,'list')); if not n then return nil,0 end
 local best,count=nil,0
 for i=1,math.min(n,500) do
  local link=visible(call(GetAuctionItemLink,'list',i))
  if type(link)=='string' and tonumber(link:match('item:(%d+)'))==id then
   local ok,_,_,stack,_,_,_,_,_,_,buy=pcall(GetAuctionItemInfo,'list',i)
   if ok then stack,buy=cantidad(stack),cantidad(buy) end
   if ok and stack and stack>0 and buy and buy>0 then local unit=math.ceil(buy/stack); best=not best and unit or math.min(best,unit); count=count+1 end
  end
 end
 return best,count
end
-- Spell API positive evidence only. Missing/false isn't proof of unknown profession recipe.
function GL.RecetaConocida976(id)
 if type(id)~='number' then return nil end
 for _,f in pairs({a=IsPlayerSpell,b=IsSpellKnown,c=C_SpellBook and C_SpellBook.IsSpellInSpellBook}) do if call(f,id)==true then return true end end
 if call(GL.HechizoConocido,id)==true then return true end
 return nil
end
-- Preserve sequence, group only consecutive identical destinations; never move a future quest across a prerequisite.
function GL.AgruparVisitas976(paso,mapa)
 local grupos={}; local prev
 for _,w in ipairs(paso and paso.wp or {}) do
  if call(GL.DestinoHecho,w)~=true and w.m==mapa and type(w.x)=='number' and type(w.y)=='number' then
   local key=string.format('%s:%.3f:%.3f',w.m,w.x,w.y)
   if not prev or prev.key~=key then prev={key=key,x=w.x,y=w.y,acciones={}}; grupos[#grupos+1]=prev end
   prev.acciones[#prev.acciones+1]=w
  else prev=nil end
 end
 return grupos
end
local function contexto()
 local out={L'Recomendaciones del personaje'}
 local free=call(GL.HuecosGenerales976)
 if type(free)=='number' and free<=4 then out[#out+1]=L'Pocos huecos generales en las bolsas: '..free end
 local talents=call(GL.PuntosTalentoLibres); if type(talents)=='number' and talents>0 then out[#out+1]=L'Puntos de talento libres: '..talents end
 local count,cost,nextLevel,nextCost=call(GL.CostesEntrenamiento); local gold=call(GetMoney)
 if type(count)=='number' and count>0 then out[#out+1]=L'Hechizos recomendados pendientes: '..count end
 if type(cost)=='number' and cost>0 and type(gold)=='number' and gold<cost then out[#out+1]=L'Oro insuficiente para el entrenamiento estimado.' end
 local function dinero(v) return call(GL.Dinero,v) or (string.format('%.2f',v/10000)..' '..L'oro') end
 local disponible=call(GL.DineroParaComprar,false)
 if type(cost)=='number' and cost>0 then
  out[#out+1]=L'Coste estimado del entrenamiento pendiente: '..dinero(cost)
  if type(gold)=='number' and gold>=cost and type(disponible)=='number' and disponible<cost then
   out[#out+1]=L'La reserva de oro limita las compras automáticas de entrenamiento.'
  end
 end
 if nextLevel then
  out[#out+1]=L'Próximo entrenamiento recomendado: nivel '..nextLevel
  if type(nextCost)=='number' and nextCost>=0 then out[#out+1]=L'Coste estimado del próximo entrenamiento: '..dinero(nextCost) end
 end
 local nivel=call(UnitLevel,'player')
 local metas=call(GL.MetasAhorro,true)
 if type(nivel)=='number' and type(metas)=='table' then
  for _,m in ipairs(metas) do
   if (m.k=='equitacion' or m.k=='montura') and not m.hecho then
    out[#out+1]=m.n..' — '..(nivel<40 and L'Objetivo de nivel 40' or L'Revisa el instructor o vendedor de monturas')
    if type(m.o)=='number' and type(m.tengo)=='number' and m.o>m.tengo then
     out[#out+1]=L'Ahorro pendiente para este objetivo: '..dinero(math.ceil((m.o-m.tengo)*10000))
    end
   end
  end
 end
 local bind=call(GetBindLocation); if bind then out[#out+1]=L'Piedra de hogar: '..bind end
 if GL.ContextoExtra976 then for _,v in ipairs(GL.ContextoExtra976()) do out[#out+1]=v end end
 out[#out+1]=L'Consulta Personaje para equipo y talentos; usa los vuelos que ya tengas desbloqueados.'
 return out
end
GL.comandos=GL.comandos or {}; local cmd=GL.comandos
cmd.profesionesjuntas=function()
 local pp=planes(); local t={L'Compra conjunta estimada (sin duplicar existencias)'}
 for _,p in ipairs(pp) do t[#t+1]=tostring(p.prof.nombre)..' '..p.nivel..'/300' end
 if #pp==0 then t[#t+1]=L'No hay planes aprendidos activos.'; return show(t) end
 local lista,n,u=GL.ComprasJuntas976(pp,inventario); local db=GuiaAventureroDB or {}; local cost,mp=GL.Coste976(lista,db.precios976)
 for _,a in ipairs(lista) do if a.falta>0 then t[#t+1]=L(a.nombre or tostring(a.id))..' #'..a.id..' x'..a.falta end end
 t[#t+1]=L'Tramos sin datos: '..n; t[#t+1]=L'Coste parcial estimado (cobre): '..cost; t[#t+1]=L'Materiales sin precio: '..mp
 if u then t[#t+1]=L'Inventario incompleto; comprueba las existencias.' end
 t[#t+1]=L'No se descuenta producción entre profesiones ni se garantizan los puntos de habilidad.'
 for _,r in ipairs(call(GL.MisRecolecciones) or {}) do if r.zonas and r.zonas[1] then t[#t+1]=tostring(r.prof.nombre)..': '..tostring(r.zonas[1].nombre)..' (/ga recoleccion)' end end
 return show(t)
end
cmd.recetasconocidas=function()
 local out={L'Recetas del plan: conocimiento confirmado por el cliente'}
 for _,p in ipairs(planes()) do for _,t in ipairs(p.prof.pasos or {}) do if t.h>p.nivel and t.sp975 then out[#out+1]=tostring(t.r975 or t.sp975)..' #'..t.sp975..' — '..(GL.RecetaConocida976(t.sp975) and L'Confirmada' or L'No confirmada') end end end
 out[#out+1]=L'No confirmada no significa que no esté aprendida.'; return show(out)
end
cmd.preciosubasta=function(q)
 local id=tonumber(q); if not id or id<=0 or id%1~=0 then return show({L'Uso: /ga preciosubasta ID con resultados de subasta visibles.'}) end
 local price,n=GL.PrecioSubastaVisible976(id)
 if not price then return show({L'No hay un precio visible compatible. No se ha cambiado el precio guardado.'}) end
 return show({L'Menor compra unitaria visible (cobre): '..price, L'Anuncios coincidentes: '..n, L'Para guardar este precio manualmente: /ga precio '..id..' '..price})
end
cmd.visitas=function()
 local _,p=call(GL.PasoActual); local map=C_Map and call(C_Map.GetBestMapForUnit,'player'); local t={L'Visitas agrupadas del paso actual (orden original)'}
 if map then for _,g in ipairs(GL.AgruparVisitas976(p,map)) do t[#t+1]=string.format('%.1f, %.1f',g.x,g.y); for _,w in ipairs(g.acciones) do t[#t+1]='  '..tostring(w.n or w.q or '?') end end end
 t[#t+1]=L'No se adelantan recogidas ni entregas de otros pasos.'; for _,v in ipairs(contexto()) do t[#t+1]=v end; return show(t)
end
cmd.contexto=function() return show(contexto()) end
-- Preserve the existing preparation command if present; fallback to the existing one in Herramientas97.
-- 9.7.6: /ga preparacion quitado (era lo mismo que el aviso «Antes de salir»)

-- Comparison of existing plans only, with identical skill and inventory inputs.
cmd.compararplanes=function()
 local db=GuiaAventureroDB or {}; local p=GL.RUTA and GL.RUTA.profesiones and GL.RUTA.profesiones[db.profesion or 1]
 local out={L"Comparación de planes disponibles"}
 local nv=p and call(GL.NivelProfesion,p)
 if not p or not p.skill or type(nv)~="number" or nv<=0 then return show({L"Abre Profesiones y selecciona una profesión aprendida."}) end
 local best,bestName
 for _,mode in ipairs(call(GL.ModalidadesProfesion975,p.skill) or {}) do
  if mode~="ruta" then
   local plan=call(GL.ConstruirPlanProfesion976,p.skill,mode)
   if plan then
    local lista,missing,unknown=GL.ComprasProfesion975(plan,nv,inventario)
    local cost,noPrice=GL.Coste976(lista,db.precios976)
    local label=GL.EtiquetaPlan975(mode)
    out[#out+1]=label..": "..cost.." | "..L"Materiales sin precio: "..noPrice.." | "..L"Tramos sin datos: "..missing
    if missing==0 and noPrice==0 and not unknown and (not best or cost<best) then best,bestName=cost,label end
   end
  end
 end
 if bestName then out[#out+1]=L"Menor coste de materiales entre los planes calculables: "..bestName end
 out[#out+1]=L"No incluye patrones, viajes, desbloqueos ni probabilidades exactas. No cambia el plan."
 return show(out)
end
