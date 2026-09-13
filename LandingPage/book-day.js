/* The opening knows the hour locally. Weather is an explicit, one-time choice. */
(() => {
  'use strict';
  let weatherLine='',pending=false;
  function clockLine(date=new Date()){
    const hour=date.getHours();
    if(hour<5)return 'It’s late where you are. The next day has arrived, but you needn’t answer it yet.';
    if(hour<9)return 'It’s morning where you are. The day has barely begun and already it wants things. Let it wait a minute.';
    if(hour<17)return 'The day is pretending it’s only work. The day is lying. There are other things happening in it.';
    if(hour<21)return 'It’s evening where you are. The day is putting things down. Catch one before it rolls under the furniture.';
    return 'It’s night where you are. You don’t have to make anything useful out of the next few minutes.';
  }
  function skyLine(code){
    if(code===0)return 'The sky is clear near you. All that room overhead, and here we are looking into a little rectangle.';
    if(code<=3)return 'There are clouds near you. The sky has brought some paper of its own.';
    if(code<=48)return 'There’s fog near you. The world has rubbed out its edges. It hasn’t gone anywhere.';
    if(code<=57)return 'It’s drizzling near you. The sky is writing very small.';
    if(code<=67)return 'It’s raining near you. The outside is tapping. It would like a word.';
    if(code<=77)return 'There’s snow near you. The sky is giving its paper away.';
    if(code<=82)return 'There are rain showers near you. The sky keeps interrupting itself.';
    if(code<=86)return 'There are snow showers near you. A few more loose Pages coming down.';
    return 'There’s a thunderstorm near you. The sky has found its loud voice.';
  }
  function render(){
    document.querySelectorAll('[data-day-opening],#hero-opener').forEach(el=>el.textContent=weatherLine||clockLine());
    document.querySelectorAll('[data-read-sky]').forEach(button=>{button.disabled=pending;button.textContent=weatherLine?'Read the weather again':'Let this Page read my weather';});
  }
  function status(text){document.querySelectorAll('[data-sky-status]').forEach(el=>el.textContent=text);}
  document.addEventListener('click',async event=>{
    if(!event.target.closest('[data-read-sky]')||pending)return;
    if(!navigator.geolocation){status('This browser can’t share a location. The clock still works.');return;}
    pending=true;render();status('Your browser will ask. You can say no.');
    try{
      const coords=await new Promise((resolve,reject)=>navigator.geolocation.getCurrentPosition(p=>resolve(p.coords),reject,{enableHighAccuracy:false,timeout:10000,maximumAge:300000}));
      const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),10000);
      let response;
      try{response=await fetch('https://api.open-meteo.com/v1/forecast?'+new URLSearchParams({latitude:coords.latitude.toFixed(2),longitude:coords.longitude.toFixed(2),current:'weather_code',timezone:'auto'}),{signal:controller.signal});}finally{clearTimeout(timeout);}
      if(!response.ok)throw new Error('weather');
      const data=await response.json(),code=data?.current?.weather_code;
      if(!Number.isInteger(code)||code<0||code>99)throw new Error('weather');
      weatherLine=skyLine(code);status('Current weather from Open-Meteo. Location used once, not stored.');
    }catch{status('I couldn’t read the sky. You can keep reading, or try again.');}
    finally{pending=false;render();}
  });
  render();document.addEventListener('visibilitychange',()=>{if(!document.hidden)render();});
})();
