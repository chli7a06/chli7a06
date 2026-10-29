(()=>{
'use strict';
if(window.__crimsonBadgeReady)return;
window.__crimsonBadgeReady=true;
const badgeCard=document.createElement('article');badgeCard.id='doj-badge';badgeCard.hidden=true;
const element=(tag,text,cls)=>{const el=document.createElement(tag);if(text)el.textContent=text;if(cls)el.className=cls;return el;};
const head=element('header',null,'credential-head');head.append(element('span','CRIMSON','credential-brand'),element('span','DEPARTMENT OF JUSTICE','credential-department'));
const body=element('div',null,'credential-body'),seal=element('img');seal.src='doj-logo.svg';seal.alt='DOJ justice emblem';
const identity=element('div',null,'credential-identity');const name=element('strong','','credential-name'),rank=element('span','','credential-rank'),number=element('span','','credential-number');
identity.append(element('small','OFFICIAL IDENTIFICATION'),name,rank,number);body.append(seal,identity);
const foot=element('footer',null,'credential-foot');foot.append(element('span','AUTHORIZED DOJ PERSONNEL'),element('span','BACKSPACE · CLOSE'));
badgeCard.append(head,body,foot);document.body.append(badgeCard);
let badgeTimer,presentation;
window.addEventListener('message',event=>{
 if(event.data?.action==='badgeHide'&&(!event.data.presentation||event.data.presentation===presentation)){badgeCard.hidden=true;clearTimeout(badgeTimer);return;}
 if(event.data?.action!=='dojBadge')return;
 const data=event.data.data||{};presentation=data.presentation;
 name.textContent=data.name||'';rank.textContent=data.rank||'';number.textContent=data.number||'';
 badgeCard.hidden=false;clearTimeout(badgeTimer);badgeTimer=setTimeout(()=>{badgeCard.hidden=true;},8000);
});
document.addEventListener('keydown',event=>{if(event.key==='Backspace'&&!badgeCard.hidden&&!['INPUT','TEXTAREA'].includes(event.target.tagName)){event.preventDefault();badgeCard.hidden=true;nui('badgeDismiss').catch(()=>{});}});
})();
