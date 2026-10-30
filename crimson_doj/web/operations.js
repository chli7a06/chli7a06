'use strict';
const opsNav=nav;
nav=function(){opsNav();if(['doj','police'].includes(session.department)&&hasPermission('vehicles_view',true)){extNav(crimsonT('OPERATIONS'),'airUnits',crimsonT('Air units'),'✈');extNav(crimsonT('OPERATIONS'),'weaponSerials',crimsonT('Weapon serial search'),'⌖');if(session.management!==false)extNav(crimsonT('OPERATIONS'),'cameraNetwork',crimsonT('Camera network'),'◉');}};
const opsShow=show;
show=async function(next,clear=true){
 if(!['airUnits','weaponSerials','cameraNetwork'].includes(next))return opsShow(next,clear);
 view=next;try{if(!session?.onduty)throw Error(crimsonT('Go on duty first'));if(next==='airUnits')return await opsAirUnits();if(next==='cameraNetwork')return await opsCameras();return opsWeapons();}catch(e){error(e);}
};
async function opsAirUnits(){
 const token=reset(crimsonT('Air units'),crimsonT('Issued helicopters · configured helipad and rank required'));const rows=await request('airUnits');if(token!==sequence)return;
 if(!rows.length){content.append(empty(crimsonT('No air units available for your rank')));return;}
 content.append(table([crimsonT('HELIPAD'),crimsonT('MODEL'),crimsonT('STATUS'),crimsonT('ACTIONS')],rows.map(row=>{
  const actions=node('div',undefined,'toolbar');
  actions.append(button(crimsonT('Set helipad waypoint'),async()=>{await nui('extendedWaypoint',row.coords);}));
  actions.append(row.active?button(crimsonT('Return issued helicopter'),async()=>{await request('airReturn',{pad:row.id});await opsAirUnits();}):button(crimsonT('Request helicopter'),async()=>{const result=await nui('airSpawn',{pad:row.id});if(!result.ok)throw Error(result.error);await opsAirUnits();},'primary'));
  return [row.label,row.model,row.active?crimsonT('ISSUED'):crimsonT('AVAILABLE'),actions];
 })));
}
function opsWeapons(){
 reset(crimsonT('Weapon serial search'),crimsonT('Online inventory observations are possession sightings, not proof of legal ownership'));
 const form=node('form',undefined,'toolbar'),serial=node('input'),submit=node('button',crimsonT('Search serial'));serial.minLength=3;serial.maxLength=80;serial.required=true;serial.placeholder=crimsonT('At least three serial characters');submit.type='submit';form.append(serial,submit);content.append(form);
 const results=node('div');content.append(results);const token=sequence;
 form.onsubmit=async event=>{event.preventDefault();submit.disabled=true;try{const rows=await request('weaponSerials',{serial:serial.value});if(token!==sequence)return;results.replaceChildren();results.append(table([crimsonT('SERIAL'),crimsonT('WEAPON'),crimsonT('LAST HOLDER CID'),crimsonT('REGISTERED NAME METADATA'),crimsonT('OBSERVED')],rows.map(r=>[r.entity_id,r.data.model,r.data.holder,r.data.registeredName||crimsonT('Not set'),stamp(r.updated_at)])));if(!rows.length)results.append(empty(crimsonT('No observed serial found'),crimsonT('Only online inventories scanned since this feature was enabled can appear.')));}catch(e){error(e);}finally{submit.disabled=false;}};
}

async function opsCameras(){
 const token=reset(crimsonT('Camera network'),crimsonT('Department cameras saved at verified in-game positions'));const data=await request('cameraCatalog');if(token!==sequence)return;
 const editor=row=>extForm(crimsonT('Configure camera'),[
  {key:'label',label:crimsonT('Camera name'),required:true,value:row?.data.label||''},
  {key:'rx',label:crimsonT('Tilt (-90 to 90)'),type:'number',value:row?.data.rx??-20},
  {key:'rz',label:crimsonT('Heading (-360 to 360)'),type:'number',value:row?.data.rz??0},
  {key:'fov',label:crimsonT('Field of view (20 to 90)'),type:'number',value:row?.data.fov??60},
  extBool('relocate',crimsonT('Move camera to my current position'),false)
 ],async values=>{await request('cameraSave',{...values,relocate:values.relocate==='yes',id:row?.entity_id,version:row?.version});await opsCameras();},crimsonT('New cameras use your server-verified position, one metre above you. Existing cameras keep their position unless you select Move.'));
 if(data.canEdit)content.append(button(crimsonT('Add camera at my position'),()=>editor(null),'primary'));
 content.append(table([crimsonT('CAMERA'),crimsonT('ACTIONS')],data.rows.map(row=>{const actions=node('div',undefined,'toolbar');actions.append(button(crimsonT('View camera'),async()=>{const result=await nui('camera',{id:row.entity_id,custom:true});if(!result.ok)throw Error(result.error);}));if(data.canEdit)actions.append(button(crimsonT('Edit camera'),()=>editor(row)),button(crimsonT('Delete camera'),async()=>{if(!window.confirm(crimsonT('Delete this camera?')))return;await request('cameraDelete',{id:row.entity_id,version:row.version});await opsCameras();}));return [row.data.label,actions];})));
}
