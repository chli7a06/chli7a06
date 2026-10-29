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
let badgeTimer,presentation;
window.addEventListener('message',event=>{
 if(event.data?.action==='badgeHide'&&(!event.data.presentation||event.data.presentation===presentation)){badgeCard.hidden=true;clearTimeout(badgeTimer);return;}
 if(event.data?.action!=='dojBadge')return;
 const data=event.data.data||{};presentation=data.presentation;
 fields[2].textContent=data.name||'';fields[3].textContent=data.rank||'';fields[4].textContent=data.number||'';
 badgeCard.hidden=false;clearTimeout(badgeTimer);badgeTimer=setTimeout(()=>{badgeCard.hidden=true;},8000);
});

document.addEventListener('keydown',event=>{if(event.key==='Backspace'&&!badgeCard.hidden&&!['INPUT','TEXTAREA'].includes(event.target.tagName)){event.preventDefault();badgeCard.hidden=true;nui('badgeDismiss').catch(()=>{});}});
})();
