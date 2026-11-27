import {test} from 'node:test';
import assert from 'node:assert/strict';
import {groupTotal} from '../dist/fare_math.mjs';
test('un grupo paga centavos exactos y no transforma tarifas pendientes en cero',()=>{
  assert.equal(groupTotal(850,3),2550);assert.equal(groupTotal(800,50),40000);
  for(const [fare,q] of [[null,1],[0,1],[850,0],[850,51],[850,1.5],[850,NaN]])assert.equal(groupTotal(fare,q),null);
});
