/* Browser translation of BookBackground, AmbientLetterFieldRenderer and
   BookPixieLayer in InsideCoverApp/BookSurfaceViews.swift. No visitor data. */
(() => {
  'use strict';
  const background=document.createElement('div');background.className='book-atmosphere';background.setAttribute('aria-hidden','true');
  const still=document.createElement('canvas'),lettersCanvas=document.createElement('canvas'),pixieCanvas=document.createElement('canvas');
  still.className='room-stars';lettersCanvas.className='room-letters';pixieCanvas.className='room-pixie';pixieCanvas.setAttribute('aria-hidden','true');
  background.append(still,lettersCanvas);
  for(const [asset,cls] of [['MarginaliaLavender','room-lavender'],['MarginaliaStar','room-star']]){
    const mark=document.createElement('img');mark.src='./assets/book/'+asset+'.webp';mark.alt='';mark.className=cls;background.append(mark);
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
  let geometryDirty=true,paused=false,lastPoint=null,lastSettle=0;
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
    geometryDirty=true;requestFrame();
  }
  function geometry(){
    const stage=document.querySelector('#book-stage');
    const board=stage?.querySelector('.book-board');
    book=board && !document.querySelector('#reading-room')?.hidden?board.getBoundingClientRect():null;
    geometryDirty=false;
  }
  function settleAt(t){
    const phase=wrap(t,19)/19;
    if(phase<.22)return smooth(phase/.22)*.94;
    if(phase<.68)return .94;
    if(phase<.86)return smooth((.86-phase)/.18)*.94;
    return 0;
  }
  function startled(t){const elapsed=t-startledAt;return elapsed<0 || elapsed>=2.6?0:elapsed<.22?smooth(elapsed/.22):smooth((2.6-elapsed)/2.38);}
  function perch(t){
    if(!book)return{x:width*.72,y:height*.16};
    const spots=[
      {x:book.left+28,y:book.top-3},
      {x:book.right-4,y:book.top+book.height*.28-7},
      {x:book.left+book.width*.36,y:book.bottom+8}
    ];
    return spots[Math.floor(t/19)%spots.length];
  }
  function pixiePosition(t,still=false){
    if(still)return perch(6.5);
    const wander={x:width*(.5+Math.sin(t*.083)*.34+Math.cos(t*.031)*.09),y:height*(.42+Math.cos(t*.067+.6)*.26+Math.sin(t*.047)*.09)};
    let p=mix(wander,perch(t),settleAt(t));
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
    if(!book || document.querySelector('dialog[open]')){lastPoint=null;return;}
    const her=pixiePosition(t,isStill),startle=isStill?0:startled(t),settle=isStill?.94:settleAt(t)*(1-startle);
    lastPoint=her;lastSettle=settle;
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
  }
  function render(stamp){
    frame=0;
    if(document.hidden){last=0;return;}
    const isStill=reduced.matches || paused;
    if(!isStill && last && stamp-last<1000/30){requestFrame();return;}
    if(geometryDirty)geometry();
    if(!isStill && last)time+=Math.min(.1,(stamp-last)/1000);
    last=stamp;drawLetters(isStill?0:time,isStill);drawPixie(isStill?6.5:time,isStill);
    if(!isStill)requestFrame();
  }
  function requestFrame(){if(!frame && !document.hidden)frame=requestAnimationFrame(render);}
  window.addEventListener('resize',resize,{passive:true});
  window.addEventListener('scroll',()=>{geometryDirty=true;requestFrame();},{passive:true});
  document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelAnimationFrame(frame);frame=0;last=0;}else requestFrame();});
  document.addEventListener('focusin',event=>{paused=!!event.target.closest('input,textarea,select,[contenteditable]');requestFrame();});
  document.addEventListener('focusout',()=>{paused=false;last=0;requestFrame();});
  document.addEventListener('pointerdown',event=>{
    if(reduced.matches || paused || !lastPoint || lastSettle<=.3 || time-startledAt<2.6 || event.target.closest('a,button,input,select,textarea,video,dialog'))return;
    if(Math.hypot(event.clientX-lastPoint.x,event.clientY-lastPoint.y)>24)return;
    flee={x:lastPoint.x>width/2?.08:.92,y:.08+Math.random()*.22};startledAt=time;requestFrame();
  });
  reduced.addEventListener('change',()=>{last=0;requestFrame();});
  const bookStage=document.querySelector('#book-stage');
  if(bookStage)new ResizeObserver(()=>{geometryDirty=true;requestFrame();}).observe(bookStage);
  new MutationObserver(()=>{geometryDirty=true;requestFrame();}).observe(document.body,{attributes:true,attributeFilter:['class']});
  new MutationObserver(()=>requestFrame()).observe(document.querySelector('.paper-dialog')||document.body,{attributes:true,attributeFilter:['open']});
  resize();
})();
