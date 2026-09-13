/* A local, downloadable Page. Reader ink never leaves the browser. */
(() => {
  'use strict';
  function imageAt(src){return new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>resolve(img);img.onerror=reject;img.src=src;});}
  function lines(ctx,text,max){
    const result=[];
    for(const paragraph of text.split(/\n/)){
      let line='';
      for(const word of paragraph.split(/\s+/)){
        if(ctx.measureText(line+(line?' ':'')+word).width<=max){line+=(line?' ':'')+word;continue;}
        if(line)result.push(line);line='';
        for(const letter of word){if(ctx.measureText(line+letter).width>max){result.push(line);line='';}line+=letter;}
      }
      result.push(line);
    }
    return result;
  }
  document.addEventListener('click',async event=>{
    const button=event.target.closest('[data-souvenir]');if(!button)return;
    const status=button.parentElement.querySelector('[data-souvenir-status]');
    button.disabled=true;status.textContent='A moment. I’m finding the edge of the paper.';
    try{
      await document.fonts.ready;
      const canvas=document.createElement('canvas');canvas.width=1200;canvas.height=1600;
      const ctx=canvas.getContext('2d');
      ctx.fillStyle='#f0dfbb';ctx.fillRect(0,0,1200,1600);
      try{const paper=await imageAt('./assets/book/paper.jpg');ctx.globalAlpha=.48;ctx.drawImage(paper,0,0,1200,1600);ctx.globalAlpha=1;}catch{}
      ctx.strokeStyle='#957447';ctx.lineWidth=2;ctx.strokeRect(65,65,1070,1470);
      ctx.fillStyle='#745836';ctx.font='22px Georgia';ctx.textAlign='center';ctx.fillText('R E E N C H A N T E D',600,150);
      try{const mark=await imageAt('./assets/book/MarginaliaFeather.webp');ctx.drawImage(mark,480,225,240,240);}catch{}
      const sentence=window.PublicEdition?.getSentence().trim();
      const text=sentence||'Look at one familiar thing until it stops being only its name.';
      ctx.fillStyle='#32271e';ctx.font='52px Georgia';let wrapped=lines(ctx,text,850);
      if(wrapped.length>11){ctx.font='42px Georgia';wrapped=lines(ctx,text,850);}
      const lineHeight=ctx.font.startsWith('42')?60:74;
      const start=800-(wrapped.length-1)*lineHeight/2;
      wrapped.forEach((line,i)=>ctx.fillText(line,600,start+i*lineHeight));
      ctx.fillStyle='#775d3f';ctx.font='italic 25px Georgia';ctx.fillText(sentence?'Your own words. A little piece of the day.':'An invitation from the public edition.',600,1290);
      ctx.font='23px Georgia';ctx.fillText('The next Page is outside.',600,1400);
      const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));
      if(!blob)throw new Error('No image');
      const url=URL.createObjectURL(blob);const anchor=document.createElement('a');anchor.href=url;anchor.download='a-page-from-reenchanted.png';document.body.append(anchor);anchor.click();anchor.remove();setTimeout(()=>URL.revokeObjectURL(url),60000);
      status.textContent='Your Page is ready. Check your downloads.';
    }catch{status.textContent='The paper caught. Please try taking the Page again.';}
    finally{button.disabled=false;}
  });
})();
