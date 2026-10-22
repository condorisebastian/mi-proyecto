import {groupTotal, money} from './fare_math.mjs';
const el = id => document.getElementById(id);
const text = (tag, value, className) => {const node=document.createElement(tag);node.textContent=value;if(className)node.className=className;return node;};
let catalog;
function renderRoutes() {
  if (!catalog) return;
  const query=el('search').value.trim().toLocaleLowerCase('es');
  const province=el('province').value;
  const quantity=Number(el('quantity').value);
  const valid=Number.isInteger(quantity)&&quantity>=1&&quantity<=50;
  el('quantity').setCustomValidity(valid?'':'Introduce entre 1 y 50 pasajes.');
  const matches=catalog.routes.filter(r=>(!province||r.province===province)&&`${r.destination} ${r.province}`.toLocaleLowerCase('es').includes(query));
  el('routes').replaceChildren();
  for (const route of matches) {
    const active=Number.isInteger(route.fare_cents)&&route.fare_cents>0;
    const card=text('article','',`route-card${active?'':' pending'}`);
    card.append(text('span',active?'TARIFA DEL PILOTO':'PRÓXIMAMENTE','route-tag'),text('h3',route.destination),text('p',route.province,'province-name'));
    card.append(text('div',active?money(route.fare_cents):'Tarifa por verificar','price'),text('span',active?'por persona':'Recorrido y servicio pendientes','unit'));
    if(active){const total=text('div','','total');total.append(text('span',valid?`${quantity} pasaje${quantity===1?'':'s'}`:'Cantidad inválida'),text('strong',valid?money(groupTotal(route.fare_cents,quantity)):'—'));card.append(total);}
    el('routes').append(card);
  }
  el('route-status').textContent=valid?`${matches.length} destino(s) · catálogo ${catalog.version}`:'La cantidad debe estar entre 1 y 50 pasajes.';
}
for(const id of ['search','province','quantity'])el(id).addEventListener('input',renderRoutes);
try {
  const response=await fetch('routes.json');if(!response.ok)throw new Error();catalog=await response.json();
  for(const name of [...new Set(catalog.routes.map(r=>r.province))].sort((a,b)=>a.localeCompare(b,'es'))) {
    const option=text('option',name);option.value=name;el('province').append(option);
  }
  renderRoutes();
}catch{el('route-status').textContent='No se pudo cargar el catálogo. Vuelve a cargar la página para intentarlo de nuevo.';}

let busy=false;
function demoTotal(){return groupTotal(Number(el('demo-route').value),Number(el('demo-quantity').value));}
function updateDemo(){const amount=demoTotal();el('demo-total').textContent=amount===null?'Revisa la cantidad':money(amount);}
for(const id of ['demo-route','demo-quantity'])el(id).addEventListener('input',updateDemo);
el('tap').addEventListener('click',async()=>{
  if(busy)return;
  const amount=demoTotal(), balance=Number(el('demo-balance').value), cents=Math.round(balance*100);
  if(amount===null||el('demo-balance').value.trim()===''||!Number.isFinite(balance)||balance<0||balance>1000000||Math.abs(balance*100-cents)>0.00001){el('demo-message').textContent='Revisa la cantidad y el saldo de prueba.';return;}
  busy=true;for(const id of ['tap','demo-balance','demo-route','demo-quantity','reset'])el(id).disabled=true;
  const display=document.querySelector('.pos-display');display.classList.remove('approved','declined');el('demo-message').textContent='Verificando saldo ficticio…';
  await new Promise(resolve=>setTimeout(resolve,650));
  if(cents<amount){display.classList.add('declined');el('demo-message').textContent='Saldo insuficiente. El saldo ficticio no cambió.';}
  else{display.classList.add('approved');el('demo-balance').value=((cents-amount)/100).toFixed(2);el('demo-message').textContent=`Pago simulado aprobado. Saldo de prueba: ${money(cents-amount)}.`;}
  busy=false;for(const id of ['tap','demo-balance','demo-route','demo-quantity','reset'])el(id).disabled=false;
});
el('reset').addEventListener('click',()=>{if(busy)return;el('demo-balance').value='25.50';el('demo-quantity').value='1';el('demo-route').value='800';document.querySelector('.pos-display').classList.remove('approved','declined');el('demo-message').textContent='Lista para leer la tarjeta';updateDemo();});
