(()=>{
'use strict';
if(window.__crimsonBadgeReady)return;
window.__crimsonBadgeReady=true;
const badgeCard=document.createElement('article');
badgeCard.id='doj-badge';badgeCard.hidden=true;
const seal=document.createElement('img');seal.src='crimson-logo.png';seal.alt='Crimson';
const badgeFields=['CRIMSON DOJ','OFFICIAL CREDENTIAL','','',''];
const fields=badgeFields.map(text=>{const p=document.createElement('div');p.textContent=text;return p;});
badgeCard.append(seal,...fields);document.body.append(badgeCard);
let badgeTimer;
window.addEventListener('message',event=>{
 if(event.data?.action!=='dojBadge')return;
 const data=event.data.data||{};
 fields[2].textContent=data.name||'';fields[3].textContent=data.rank||'';fields[4].textContent=data.number||'';
 badgeCard.hidden=false;clearTimeout(badgeTimer);badgeTimer=setTimeout(()=>{badgeCard.hidden=true;},8000);
});

})();
