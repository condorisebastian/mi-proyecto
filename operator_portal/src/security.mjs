import {randomBytes,createHash,timingSafeEqual} from 'node:crypto';
import {PortalError} from './backend.mjs';
export const MAX_FILE=5*1024*1024;
export const token=()=>randomBytes(32).toString('hex');
export const digest=value=>createHash('sha256').update(value).digest('hex');
export function equal(a,b) { if(typeof a!=='string'||typeof b!=='string')return false;const x=Buffer.from(a),y=Buffer.from(b);return x.length===y.length&&timingSafeEqual(x,y); }
export function cookieValue(header,name) { return String(header||'').split(';').map(s=>s.trim()).find(s=>s.startsWith(name+'='))?.slice(name.length+1); }
export function pointsCents(value) {
  if(typeof value!=='string' || !/^\d{1,4}(\.\d{1,2})?$/.test(value)) throw new PortalError('Introduce puntos con hasta dos decimales.');
  const [whole,decimal='']=value.split('.');
  const amount=Number(whole)*100+Number(decimal.padEnd(2,'0'));
  if(amount<50 || amount>100000 || amount%50!==0) throw new PortalError('Usa entre 0.50 y 1000 puntos, en múltiplos de 0.50.');
  return amount;
}
export function validateFile(bytes,mime) {
  if(bytes.length<16 || bytes.length>MAX_FILE) throw new PortalError('El archivo debe pesar entre 16 bytes y 5 MB.');
  const valid=mime==='image/png' && bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))
    || mime==='image/jpeg' && bytes[0]===255 && bytes[1]===216 && bytes.at(-2)===255 && bytes.at(-1)===217
    || mime==='application/pdf' && bytes.subarray(0,5).toString()==='%PDF-' && bytes.subarray(-1024).includes(Buffer.from('%%EOF'));
  if(!valid) throw new PortalError('Adjunta una imagen PNG/JPG o un PDF válido.');
  return mime==='image/png'?'.png':mime==='image/jpeg'?'.jpg':'.pdf';
}
export async function readBody(request,limit=32768) {
  const chunks=[]; let length=0;
  for await(const chunk of request) { length+=chunk.length; if(length>limit) throw new PortalError('El archivo o los datos superan el tamaño permitido.',413); chunks.push(chunk); }
  return Buffer.concat(chunks);
}
export async function readJson(request) {
  if(request.headers['content-type']?.split(';')[0]!=='application/json') throw new PortalError('Se requieren datos JSON.',415);
  try { const data=JSON.parse((await readBody(request)).toString()); if(!data || Array.isArray(data) || typeof data!=='object') throw new Error(); return data; }
  catch(error) { if(error instanceof PortalError) throw error; throw new PortalError('Los datos enviados no son válidos.'); }
}
export function demoPdf(customer,kind) {
  // PDF de texto generado en código; no imita un carnet oficial ni una firma.
  const clean=value=>String(value).normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^\x20-\x7e]/g,'').replace(/[()\\]/g,' ');
  const lines=['Mi Pasaje - Documento FICTICIO','Sin validez academica ni legal',kind==='carnet'?'Carnet estudiantil de demostracion':'Matricula de demostracion',
    customer.first_name+' '+customer.last_name,customer.identity_document,customer.institution,customer.student_id,customer.enrollment_id,customer.student_card,'Solo para probar el portal de atencion.'];
  const stream='BT /F1 16 Tf 50 780 Td '+lines.map((v,i)=>(i?'0 -30 Td ':'')+`(${clean(v)}) Tj`).join('\n')+' ET';
  const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`];
  let pdf='%PDF-1.4\n'; const offsets=[0];
  objects.forEach((obj,i)=>{offsets.push(Buffer.byteLength(pdf));pdf+=`${i+1} 0 obj\n${obj}\nendobj\n`;});
  const xref=Buffer.byteLength(pdf); pdf+=`xref\n0 6\n0000000000 65535 f \n`+offsets.slice(1).map(x=>String(x).padStart(10,'0')+' 00000 n \n').join('')+`trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf);
}
