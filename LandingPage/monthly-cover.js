/* The same local-calendar selection and first-official-cover default as the app. */
(() => {
  'use strict';
  const catalogue=window.PublicCoverCatalogue;
  if(!catalogue)return;
  function select(date){return catalogue.schedule.find(c=>c.year===date.getFullYear()&&c.month===date.getMonth()+1)||catalogue.fallback;}
  const titlePage=document.querySelector('#frontispiece');
  titlePage.dataset.chapter='The title page';
  const cover=document.createElement('section');cover.id='cover';cover.dataset.chapter='The monthly cover';cover.dataset.kind='cover';
  const link=document.createElement('a');link.className='monthly-cover-face';link.href='#frontispiece';link.setAttribute('aria-label','Open the monthly cover');
  const image=document.createElement('img');image.className='monthly-cover-art';image.width=1300;image.height=1920;image.fetchPriority='high';
  const matter=document.createElement('div');matter.className='monthly-cover-matter';
  const corner=document.createElement('span');corner.className='monthly-cover-corners';corner.setAttribute('aria-hidden','true');
  link.append(image,matter,corner);cover.append(link);titlePage.before(cover);
  let monthKey='';
  function refresh(){
    const now=new Date(),key=now.getFullYear()+'-'+now.getMonth();if(key===monthKey)return;
    monthKey=key;const choice=select(now);
    const dateLine=now.toLocaleDateString('en-US',{month:'long',year:'numeric'});
    const render=(face)=>{
      const art=face.querySelector('.monthly-cover-art'),text=face.querySelector('.monthly-cover-matter');
      art.src=choice.src;art.alt=choice.title+' — '+dateLine+', the app’s monthly cover';
      face.classList.toggle('has-cover-matter',choice.includesMatter);face.classList.toggle('has-parchment-title',choice.parchmentTitle);
      text.replaceChildren();text.hidden=choice.includesMatter;
      if(!choice.includesMatter){
        for(const [tag,className,value] of [['p','cover-imprint','The Book of You'],['p','cover-reader','The public edition'],['p','cover-issue',choice.monthLine==='nil'?'Working field book':choice.monthLine],['h2','cover-title',choice.title],['p','cover-subtitle',choice.subtitle],['p','cover-date',dateLine]]){const el=document.createElement(tag);el.className=className;el.textContent=value;text.append(el);}
      }
      face.setAttribute('aria-label','Open '+choice.title+' — '+dateLine);
    };
    document.querySelectorAll('.monthly-cover-face').forEach(render);
  }
  window.PublicMonthlyCover={select,refresh};refresh();
  // An open tab changes with the calendar too, without disturbing its reading place.
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});
  setInterval(refresh,60000);
})();
