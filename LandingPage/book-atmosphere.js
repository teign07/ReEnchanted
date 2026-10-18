/* Browser translation of BookBackground, AmbientLetterFieldRenderer and
   BookPixieLayer in InsideCoverApp/BookSurfaceViews.swift. No visitor data. */
(() => {
  'use strict';
  const background=document.createElement('div');background.className='book-atmosphere';background.setAttribute('aria-hidden','true');
  const still=document.createElement('canvas'),lettersCanvas=document.createElement('canvas'),pixieCanvas=document.createElement('canvas');
  still.className='room-stars';lettersCanvas.className='room-letters';pixieCanvas.className='room-pixie';pixieCanvas.setAttribute('aria-hidden','true');
  background.append(still,lettersCanvas);
  for(const [asset,cls] of [['MarginaliaLavender','room-lavender'],['MarginaliaStar','room-star']]){
    const id=asset.replace(/([a-z])([A-Z])/g,'$1-$2').toLowerCase();
    const mark=document.createElement('img');mark.src=window.PublicMarginalia?.marks.find(drawing=>drawing.id===id)?.src || './assets/book/'+asset+'.webp';mark.alt='';mark.className=cls;background.append(mark);
  }
  document.body.prepend(background);document.body.append(pixieCanvas);
  const bg=still.getContext('2d'),ink=lettersCanvas.getContext('2d'),light=pixieCanvas.getContext('2d');
  if(!bg || !ink || !light)return;
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  const clamp=x=>Math.max(0,Math.min(1,x));
  const smooth=x=>{x=clamp(x);return x*x*(3-2*x);};
  const step=(a,b,x)=>smooth((x-a)/(b-a));
  const random=(seed,salt)=>{const n=Math.sin(seed*12.9898+salt*78.233)*43758.5453;return n-Math.floor(n);};
  const mix=(a,b,t)=>({x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t});
  const wrap=(v,range)=>((v%range)+range)%range;
  const wrapped=(p,margin)=>({x:wrap(p.x+margin,width+margin*2)-margin,y:wrap(p.y+margin,height+margin*2)-margin});
  const glyphs='REENCHANTEDBOOKOFYOUPAGESKEPTSTORY';
  const colors=['243,186,110','255,219,143','92,204,204','179,148,250'];
  const rgba=(rgb,a)=>`rgba(${rgb},${clamp(a)})`;
  const lamp='255,230,173',haloColor='199,184,133',wingColor='255,240,204',contour='51,36,20';
  let width=0,height=0,book=null,frame=0,last=0,time=6.5,startledAt=-100,flee={x:.9,y:.12};
  let geometryDirty=true,paused=false,lastPoint=null;
  // The canvas stays transparent to the Book. Only her little resting place
  // receives a click; a focused or hovered Pixie waits for the reader.
  const catcher=document.createElement('button');
  catcher.type='button';catcher.className='pixie-catcher';catcher.hidden=true;
  catcher.setAttribute('aria-label','Startle the Punctuation Pixie');
  catcher.setAttribute('aria-controls','pixie-scrap');
  catcher.setAttribute('aria-expanded','false');
  const hint=document.createElement('span');hint.className='pixie-hint';hint.textContent='What’s she carrying?';hint.setAttribute('aria-hidden','true');catcher.append(hint);
  const scrap=document.createElement('aside');scrap.id='pixie-scrap';scrap.className='pixie-scrap';scrap.hidden=true;scrap.setAttribute('aria-label','Something the Pixie dropped');
  const announcement=document.createElement('span');announcement.className='pixie-announcement';announcement.setAttribute('role','status');announcement.setAttribute('aria-atomic','true');
  document.body.append(catcher,scrap,announcement);
  let heldPoint=null,hovering=false,catches=0,pocket=[],lastGift='',lastWord='',personal=false,summonedAt=-100,summonedPoint=null;
  let burstAt=-100,burstPoint=null,burstGlyphs=[];
  const gifts=[
    {id:'comma',mark:',',title:'A comma, still warm',line:'She was saving a pause for later. Here. You can have it.',secret:'There. One small breath. The sentence will wait.'},
    {id:'stop',mark:'.',title:'A full stop got loose',line:'Put it down carefully. Anything it lands on thinks it’s finished.',secret:'You put it here. Good. The day can keep going.'},
    {id:'question',mark:'?',title:'A question with no owner',line:'It’s been following her all morning. Perhaps it wants you.',secret:'What nearby thing have you stopped seeing because it’s always there?'},
    {id:'ellipsis',mark:'…',title:'Three dots. No explanation.',line:'She took these from a sentence that wasn’t done. I can hear it looking for them.',secret:'Somewhere in me, a sentence is holding its breath.'},
    {id:'dare',mark:'!',title:'A word wants out',line:'She found this in Wicker’s pocket. It’s still trying to shout.',href:'#first-dare',action:'Read Wicker’s dare'},
    {id:'cats',mark:'“ ”',title:'Something is looking back',line:'She stole a pair of quotation marks. There’s something alive between them.',href:'#first-cats',action:'Look between the marks'},
    {id:'fae',mark:';',title:'A note from her own pocket',line:'She dropped her name. Don’t let it blow away.',href:'#note-punctuation-pixie',action:'Read about the Punctuation Pixie'}
  ];
  function refillPocket(){
    pocket=gifts.slice();
    for(let i=pocket.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[pocket[i],pocket[j]]=[pocket[j],pocket[i]];}
    if(pocket[pocket.length-1]?.id===lastGift)[pocket[0],pocket[pocket.length-1]]=[pocket[pocket.length-1],pocket[0]];
  }
  function gift(){
    const words=[...new Set((window.PublicEdition?.getSentence?.()||'').match(/[\p{L}\p{M}]+(?:[’'-][\p{L}\p{M}]+)*/gu)||[])].filter(word=>word.length>=3 && word.length<=22 && word!==lastWord);
    if(words.length && (catches===1 || catches%3===0)){
      const word=words[Math.floor(Math.random()*words.length)];lastWord=word;
      return {id:'reader',mark:word,title:'She had one of your words',line:'“'+word+'” fell out of her hands. You wrote it. She liked the shape.',secret:'I’ve put it back. Your sentence still has all its words.',personal:true};
    }
    // The first empty-handed catch teaches the little punctuation trick.
    if(catches===1){lastGift='comma';return gifts[0];}
    if(!pocket.length)refillPocket();
    // The first comma has already been seen, even though it wasn't drawn.
    if(pocket[pocket.length-1]?.id===lastGift && pocket.length>1)[pocket[0],pocket[pocket.length-1]]=[pocket[pocket.length-1],pocket[0]];
    const found=pocket.pop();lastGift=found.id;return found;
  }
  function tuckScrap(restore=false){
    const focused=scrap.contains(document.activeElement);
    scrap.hidden=true;scrap.replaceChildren();personal=false;catcher.setAttribute('aria-expanded','false');
    announcement.textContent='';
    if(restore && focused && !catcher.hidden)catcher.focus({preventScroll:true});
  }
  function placeScrap(){
    if(scrap.hidden)return;
    const bounds=scrap.getBoundingClientRect(),narrow=width<760;
    const x=narrow?(width-bounds.width)/2:(book?.right||width)-22;
    const y=narrow?height-bounds.height-20:(book?.top||40)+Math.min(140,(book?.height||400)*.24);
    scrap.style.left=Math.max(12,Math.min(width-bounds.width-12,x))+'px';
    scrap.style.top=Math.max(12,Math.min(height-bounds.height-12,y))+'px';
  }
  function drop(found,origin,keyboard){
    tuckScrap();personal=!!found.personal;
    const close=document.createElement('button');close.type='button';close.className='pixie-scrap-close';close.setAttribute('aria-label','Tuck away the Pixie’s scrap');close.textContent='×';close.addEventListener('click',()=>tuckScrap(true));
    const eyebrow=document.createElement('p');eyebrow.className='pixie-scrap-eyebrow';eyebrow.textContent=catches%4===0?'Her pocket has a hole':'Something fell';
    const mark=document.createElement('button');mark.type='button';mark.className='pixie-found-mark';mark.textContent=found.mark;mark.setAttribute('aria-label',found.personal?'Put your word back':'Touch the fallen punctuation');
    if(found.personal)mark.classList.add('is-word');
    const title=document.createElement('h2');title.textContent=found.title;
    const line=document.createElement('p');line.className='pixie-scrap-line';line.textContent=found.line;
    const action=document.createElement(found.href?'a':'button');action.className='pixie-scrap-action';
    if(found.href){action.href=found.href;action.textContent=found.action+' ↗';action.addEventListener('click',()=>tuckScrap());}
    else {action.type='button';action.textContent=found.personal?'Put it back':'Touch the '+({comma:'comma',stop:'full stop',question:'question mark',ellipsis:'dots'}[found.id]||'mark');}
    function unfold(){
      if(found.href){action.click();return;}
      line.textContent=found.secret;mark.disabled=true;action.hidden=true;scrap.classList.add('is-unfolded');
      announcement.textContent=found.secret;window.BookSounds?.play('ink');
      close.focus({preventScroll:true});
      if(!reduced.matches){burstAt=time;burstPoint={x:origin.x,y:origin.y};burstGlyphs=['·',',','·'];requestFrame();}
    }
    mark.addEventListener('click',unfold);if(!found.href)action.addEventListener('click',unfold);
    scrap.classList.remove('is-unfolded');scrap.append(close,eyebrow,mark,title,line,action);scrap.hidden=false;placeScrap();catcher.setAttribute('aria-expanded','true');
    announcement.textContent=found.title+'. '+found.line;
    if(!reduced.matches){
      const bounds=scrap.getBoundingClientRect();
      scrap.animate([{transform:`translate(${origin.x-bounds.left-bounds.width/2}px,${origin.y-bounds.top}px) rotate(-18deg) scale(.12)`,opacity:0},{transform:'translate(0,9px) rotate(3deg) scale(1.02)',opacity:1,offset:.8},{transform:'translate(0,0) rotate(-2deg) scale(1)',opacity:1}],{duration:760,easing:'cubic-bezier(.2,.7,.2,1)'});
    }
    if(keyboard)close.focus({preventScroll:true});
  }
  function startlePixie(keyboard=false){
    if(!lastPoint || catcher.hidden || time-startledAt<2.6)return;
    const origin={...lastPoint};heldPoint=null;hovering=false;catches++;
    flee={x:origin.x>width/2?.08:.92,y:.08+Math.random()*.22};startledAt=time;
    burstAt=time;burstPoint=origin;burstGlyphs=catches%4===0?['!','?',',',';','…','!','.',',']:['·',',','·','!','·',';'];
    window.BookSounds?.play('peek');drop(gift(),origin,keyboard);requestFrame();
  }
  function syncCatcher(her,settle){
    const focused=document.activeElement===catcher;
    const free=!paused && time-startledAt>=2.6 && (settle>.3 || focused || hovering);
    const onscreen=her.x>=24 && her.x<=width-24 && her.y>=24 && her.y<=height-24;
    // Never swallow a bookmark, a Keep, or another control under her light.
    const obstructed=free && [her,{x:her.x-18,y:her.y},{x:her.x+18,y:her.y},{x:her.x,y:her.y-18},{x:her.x,y:her.y+18}].some(point=>document.elementsFromPoint(point.x,point.y).some(el=>el!==catcher && !catcher.contains(el) && el.closest('a,button,input,select,textarea,video,dialog,.pixie-scrap')));
    catcher.hidden=!free || !onscreen || obstructed;
    if(!catcher.hidden){catcher.style.left=her.x+'px';catcher.style.top=her.y+'px';}
  }
  catcher.addEventListener('pointerenter',()=>{hovering=true;heldPoint=lastPoint?{...lastPoint}:null;});
  catcher.addEventListener('pointerleave',()=>{hovering=false;if(document.activeElement!==catcher)heldPoint=null;});
  catcher.addEventListener('focus',()=>{heldPoint=lastPoint?{...lastPoint}:null;requestFrame();});
  catcher.addEventListener('blur',()=>{if(!hovering)heldPoint=null;requestFrame();});
  catcher.addEventListener('pointerdown',event=>event.stopPropagation());
  catcher.addEventListener('click',event=>{event.stopPropagation();startlePixie(event.detail===0);});
  document.addEventListener('keydown',event=>{if(event.key==='Escape' && !scrap.hidden){event.preventDefault();tuckScrap(true);}});
  document.addEventListener('click',event=>{if(personal && event.target.closest('[data-erase-ink]'))tuckScrap();});
  document.addEventListener('input',event=>{
    if(reduced.matches || !event.target.matches('[data-capture-form] textarea') || !event.data?.includes('!'))return;
    const rect=event.target.getBoundingClientRect();summonedPoint={x:Math.min(width-30,rect.right+14),y:Math.max(30,rect.top-14)};summonedAt=time;requestFrame();
  });
  function ellipse(ctx,x,y,rx,ry,fill,stroke=null,lineWidth=1){ctx.beginPath();ctx.ellipse(x,y,Math.max(0,rx),Math.max(0,ry),0,0,Math.PI*2);if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=lineWidth;ctx.stroke();}}
  function resize(){
    width=innerWidth;height=innerHeight;const dpr=Math.min(devicePixelRatio||1,1.75);
    for(const canvas of [still,lettersCanvas,pixieCanvas]){canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);canvas.style.width=width+'px';canvas.style.height=height+'px';canvas.getContext('2d').setTransform(dpr,0,0,dpr,0,0);}
    bg.clearRect(0,0,width,height);bg.globalCompositeOperation='lighter';
    // Exact StarSpeckle distribution and seven open LabyrinthBackdrop arcs.
    for(let i=0;i<72;i++){const r=(i%3+1)/2;ellipse(bg,width*((i*37)%100)/100+r,height*((i*61)%100)/100+r,r,r,rgba('243,186,110',.165));}
    bg.strokeStyle=rgba('243,186,110',.1);bg.lineWidth=1;
    const cx=width/2+120,cy=height/2-260;
    for(let i=0;i<7;i++){bg.beginPath();bg.arc(cx,cy,380*.46-i*380*.065,(i*18+20)*Math.PI/180,(i*18+300)*Math.PI/180);bg.stroke();}
    geometryDirty=true;heldPoint=null;placeScrap();requestFrame();
  }
  function geometry(){
    const stage=document.querySelector('#book-stage');
    const board=stage?.querySelector('.book-board');
    book=board && !document.querySelector('#reading-room')?.hidden?board.getBoundingClientRect():null;
    geometryDirty=false;
  }
  function settleAt(t){
    const phase=wrap(t,19)/19;
    if(phase<.22)return smooth(phase/.22);
    if(phase<.68)return 1;
    if(phase<.86)return smooth((.86-phase)/.18);
    return 0;
  }
  function startled(t){const elapsed=t-startledAt;return elapsed<0 || elapsed>=2.6?0:elapsed<.22?smooth(elapsed/.22):smooth((2.6-elapsed)/2.38);}
  function perch(t){
    if(!book)return{x:width*.72,y:height*.16};
    const spots=[
      {x:book.left+28,y:Math.max(28,book.top-26)},
      book.right+52<width?{x:book.right+28,y:book.top+book.height*.28-7}:{x:book.right-28,y:Math.max(28,book.top-26)},
      {x:book.left+book.width*.36,y:Math.min(height-28,book.bottom+28)}
    ];
    return spots[Math.floor(t/19)%spots.length];
  }
  function pixiePosition(t,still=false){
    if(heldPoint)return heldPoint;
    if(still)return perch(6.5);
    const wander={x:width*(.5+Math.sin(t*.083)*.34+Math.cos(t*.031)*.09),y:height*(.42+Math.cos(t*.067+.6)*.26+Math.sin(t*.047)*.09)};
    let p=mix(wander,perch(t),settleAt(t));
    const elapsed=t-summonedAt;
    if(summonedPoint && elapsed>=0 && elapsed<7){const eagerness=elapsed<.35?smooth(elapsed/.35):smooth((7-elapsed)/6.65);p=mix(p,{x:summonedPoint.x+Math.cos(t*3.1)*9,y:summonedPoint.y+Math.sin(t*4.3)*6},eagerness);}
    p=mix(p,{x:width*flee.x,y:height*flee.y},startled(t));
    return p;
  }
  function gatherAt(t){const phase=wrap(t,16)/16;return clamp(step(.12,.30,phase)*(1-step(.70,.90,phase)));}
  function letterShepherd(t,count,gather){
    const seed=Math.floor(t/16)%count+1;
    const wander={x:width*(.5+Math.sin(t*.071)*.32+Math.cos(t*.029)*.08),y:height*(.46+Math.cos(t*.063+.7)*.24+Math.sin(t*.041)*.08)};
    return wrapped(mix(wander,{x:width*(.08+random(seed,1)*.84),y:height*(.08+random(seed,2)*.82)},gather*.86),50);
  }
  function drawLetters(t,isStill){
    ink.clearRect(0,0,width,height);ink.globalCompositeOperation='lighter';
    const count=Math.min(30,Math.max(16,Math.floor(width*height/26000)));
    const gather=isStill?0:gatherAt(t),shepherd=letterShepherd(t,count,gather),letters=[];
    for(let i=0;i<count;i++){
      const seed=i+1,depth=.44+random(seed,0)*.72,scale=13+24*depth;
      const base={x:width*(.06+random(seed,1)*.88),y:height*(.06+random(seed,2)*.88)};
      const wander=wrapped({x:base.x+Math.sin(t*(.058+random(seed,3)*.044)+seed*1.7)*scale+Math.cos(t*.032+seed)*scale*.5,y:base.y+Math.cos(t*(.050+random(seed,4)*.036)+seed*1.3)*scale+Math.sin(t*.034+seed*.6)*scale*.44},34);
      const dx=shepherd.x-wander.x,dy=shepherd.y-wander.y;
      const pull=gather*step(1,0,Math.hypot(dx,dy)/(150+96*depth));
      const point=wrapped({x:wander.x+dx*pull*.88+Math.sin(t*1.65+seed)*pull*34,y:wander.y+dy*pull*.88+Math.cos(t*1.32+seed*.8)*pull*29},40);
      const size=(7+random(seed,5)*9)*(.72+depth*.62),flash=Math.min(1,pull*.82),color=colors[i%4];
      const alpha=Math.min(.62,.13+random(seed,7)*.20+flash*.34)*(isStill?.36:.78);
      ink.save();ink.translate(point.x,point.y);ink.rotate(Math.sin(t*(.10+random(seed,6)*.10)+seed)*.30+flash*.20);
      ink.font=`600 ${size*(1+flash*.18)}px Georgia, serif`;ink.textAlign='center';ink.textBaseline='middle';ink.fillStyle=rgba(color,alpha);
      ink.shadowColor=rgba(color,.20+flash*.34);ink.shadowBlur=3+depth*5+flash*7;ink.fillText(glyphs[i%glyphs.length],0,0);ink.restore();
      letters.push({...point,size,color});
    }
    if(isStill)return;
    let collisions=0;
    for(let a=0;a<letters.length-1 && collisions<4;a++)for(let b=a+1;b<letters.length && collisions<4;b++){
      const first=letters[a],second=letters[b],distance=Math.hypot(first.x-second.x,first.y-second.y),threshold=(first.size+second.size)*.42+6;
      if(distance>=threshold)continue;
      const seed=a*31+b*17,strength=Math.min(1,(1-distance/threshold)*(.48+Math.max(0,Math.sin(t*14.5+seed))*.72));
      if(strength<.14)continue;
      const x=(first.x+second.x)/2,y=(first.y+second.y)/2;
      ellipse(ink,x,y,1.8+3.4*strength,1.8+3.4*strength,rgba('255,255,255',.66*strength));
      for(let spark=0;spark<6;spark++){const n=seed+spark*2.7,angle=n+t*1.75,r=(3+random(n,1)*14)*strength,radius=(.8+random(n,2)*1.7)*strength;ellipse(ink,x+Math.cos(angle)*r,y+Math.sin(angle)*r,radius,radius,rgba(spark%2?first.color:second.color,.88*strength));}
      collisions++;
    }
  }
  function drawPixie(t,isStill){
    light.clearRect(0,0,width,height);
    if(!book || document.querySelector('dialog[open]')){lastPoint=null;catcher.hidden=true;tuckScrap();heldPoint=null;return;}
    const her=pixiePosition(t,isStill),startle=isStill?0:startled(t),settle=isStill?1:settleAt(t)*(1-startle);
    lastPoint=her;
    syncCatcher(her,settle);
    if(!isStill)for(let i=10;i>=1;i--){const past=pixiePosition(t-i*.09),fade=(11-i)/10,r=1.1+fade*2.6;ellipse(light,past.x,past.y,r,r,rgba(lamp,fade*.3*(1-settle*.7)));}
    light.save();light.translate(her.x,her.y);
    const beatRate=15.5-settle*13.6+startle*9,reach=1-settle*.55,flap=(Math.sin(t*beatRate)*.5+.5)*reach;
    const pulse=1+Math.sin(t*2.4)*.06+startle*.35,halo=22*pulse+settle*3;
    const glow=light.createRadialGradient(0,0,0,0,0,halo);
    glow.addColorStop(0,rgba(lamp,.55));glow.addColorStop(.34,rgba(lamp,.26));glow.addColorStop(.62,rgba(haloColor,.16));glow.addColorStop(1,rgba(lamp,0));
    light.shadowColor=rgba(lamp,.55+startle*.25);light.shadowBlur=halo*.55;ellipse(light,0,0,halo,halo,glow);light.shadowBlur=0;
    const span=15+settle*1.5;
    for(const side of [-1,1]){
      light.save();light.scale(side,1);light.rotate((-8-54*flap)*Math.PI/180);
      ellipse(light,2.2+span/2,-span*.46+span*.31,span/2,span*.31,rgba(wingColor,.32+startle*.14),rgba(lamp,.38),.6);
      light.beginPath();light.moveTo(2.6,0);light.quadraticCurveTo(2.2+span*.5,-span*.24,2.2+span*.92,-span*.06);light.strokeStyle=rgba(lamp,.26);light.lineWidth=.5;light.stroke();light.restore();
    }
    const core=5.2*pulse;ellipse(light,0,0,core+.7,core+.7,rgba(contour,.3));
    const coreLight=light.createRadialGradient(0,0,0,0,0,core);coreLight.addColorStop(0,'rgba(255,255,255,.95)');coreLight.addColorStop(.5,rgba(lamp,.92));coreLight.addColorStop(1,rgba(lamp,.4));ellipse(light,0,0,core,core,coreLight);
    for(let mote=0;mote<4;mote++){const drift=t*1.6+mote*1.7,r=9+mote*3.4+startle*14,radius=.7+.45*Math.sin(t*3+mote*1.3),twinkle=.32+.34*Math.sin(t*4.5+mote);ellipse(light,Math.cos(drift)*r,Math.sin(drift*.8)*r*.75+3,radius,radius,rgba('173,120,46',Math.max(0,twinkle)*(.8-settle*.3)));}
    light.restore();
    const elapsed=t-burstAt;
    if(!isStill && burstPoint && elapsed>=0 && elapsed<1.6){
      light.save();light.font='600 19px Georgia,serif';light.textAlign='center';
      burstGlyphs.forEach((glyph,i)=>{const angle=i*Math.PI*2/burstGlyphs.length-.8,distance=18+elapsed*(38+i*8);light.fillStyle=rgba(i%2?lamp:'179,148,250',1-elapsed/1.6);light.fillText(glyph,burstPoint.x+Math.cos(angle)*distance,burstPoint.y+Math.sin(angle)*distance+elapsed*elapsed*55);});
      light.restore();
    }
  }
  function render(stamp){
    frame=0;
    if(document.hidden){last=0;return;}
    const isStill=reduced.matches || (paused && time-summonedAt>=7);
    if(!isStill && last && stamp-last<1000/30){requestFrame();return;}
    if(geometryDirty)geometry();
    if(last)time+=Math.min(.1,(stamp-last)/1000);
    last=stamp;drawLetters(isStill?0:time,isStill);drawPixie(isStill?6.5:time,isStill);
    if(!isStill || time-startledAt<2.6)requestFrame();
  }
  function requestFrame(){if(!frame && !document.hidden)frame=requestAnimationFrame(render);}
  window.addEventListener('resize',resize,{passive:true});
  window.addEventListener('scroll',()=>{geometryDirty=true;requestFrame();},{passive:true});
  document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelAnimationFrame(frame);frame=0;last=0;}else requestFrame();});
  document.addEventListener('focusin',event=>{paused=!!event.target.closest('input,textarea,select,[contenteditable]');requestFrame();});
  document.addEventListener('focusout',()=>{paused=false;last=0;requestFrame();});
  reduced.addEventListener('change',()=>{last=0;requestFrame();});
  const bookStage=document.querySelector('#book-stage');
  if(bookStage)new ResizeObserver(()=>{geometryDirty=true;requestFrame();}).observe(bookStage);
  new MutationObserver(()=>{geometryDirty=true;requestFrame();}).observe(document.body,{attributes:true,attributeFilter:['class']});
  new MutationObserver(()=>requestFrame()).observe(document.querySelector('.paper-dialog')||document.body,{attributes:true,attributeFilter:['open']});
  resize();
})();
