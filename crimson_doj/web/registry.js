'use strict';
const registryNav=nav;
nav=function(){registryNav();if(['doj','police'].includes(session.department)&&hasPermission('vehicles_view',true)){
 extNav('OPERATIONS','weaponSerials','Weapon serial search','⌖');
 if(session.management!==false)extNav('OPERATIONS','cameraNetwork','Camera network','◉');
}};
const registryShow=show;
show=async function(next,clear=true){
 if(!['weaponSerials','cameraNetwork'].includes(next))return registryShow(next,clear);
 view=next;try{if(!session?.onduty)throw Error('Go on duty first');if(next==='cameraNetwork')return await opsCameras();return opsWeapons();}catch(e){error(e);}
};
function opsWeapons(){
 reset('Weapon serial search','Online inventory observations are possession sightings, not proof of legal ownership');
 const form=node('form',undefined,'toolbar'),serial=node('input'),submit=node('button','Search serial');serial.minLength=3;serial.maxLength=80;serial.required=true;serial.placeholder='At least three serial characters';submit.type='submit';form.append(serial,submit);content.append(form);
 const results=node('div');content.append(results);const token=sequence;
 form.onsubmit=async event=>{event.preventDefault();submit.disabled=true;try{const rows=await request('weaponSerials',{serial:serial.value});if(token!==sequence)return;results.replaceChildren();results.append(table(['SERIAL','WEAPON','LAST OBSERVED HOLDER','REGISTERED NAME METADATA','OBSERVED'],rows.map(r=>[r.entity_id,r.data.model,textCell(r.data.holderName||r.data.holder,r.data.holder),r.data.registeredName||'Not set',stamp(r.updated_at)])));if(!rows.length)results.append(empty('No observed serial found','Only online inventories scanned since this feature was enabled can appear.'));}catch(e){error(e);}finally{submit.disabled=false;}};
}

async function opsCameras(){
 const token=reset('Camera network','Department cameras saved at verified in-game positions');const data=await request('cameraCatalog');if(token!==sequence)return;
 const editor=row=>extForm('Configure camera',[
  {key:'label',label:'Camera name',required:true,value:row?.data.label||''},
  {key:'rx',label:'Tilt (-90 to 90)',type:'number',value:row?.data.rx??-20},
  {key:'rz',label:'Heading (-360 to 360)',type:'number',value:row?.data.rz??0},
  {key:'fov',label:'Field of view (20 to 90)',type:'number',value:row?.data.fov??60},
  extBool('relocate','Move camera to my current position',false)
 ],async values=>{await request('cameraSave',{...values,relocate:values.relocate==='yes',id:row?.entity_id,version:row?.version});await opsCameras();},'New cameras use your server-verified position, one metre above you. Existing cameras keep their position unless you select Move.');
 if(data.canEdit)content.append(button('Add camera at my position',()=>editor(null),'primary'));
 content.append(table(['CAMERA','ACTIONS'],data.rows.map(row=>{const actions=node('div',undefined,'toolbar');actions.append(button('View camera',async()=>{const result=await nui('camera',{id:row.entity_id,custom:true});if(!result.ok)throw Error(result.error);}));if(data.canEdit)actions.append(button('Edit camera',()=>editor(row)),button('Delete camera',async()=>{if(!window.confirm('Delete this camera?'))return;await request('cameraDelete',{id:row.entity_id,version:row.version});await opsCameras();}));return [row.data.label,actions];})));
}
