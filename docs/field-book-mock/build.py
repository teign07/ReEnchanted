import json,re,base64,mimetypes
rooms=json.load(open('a/rooms.json'))
html=open('template.html').read().replace('/*ROOMS*/[]',json.dumps(rooms))
def inline(m):
    p=m.group(1); mt='image/png' if p.endswith('.png') else 'image/jpeg'
    return 'src="data:%s;base64,%s"'%(mt,base64.b64encode(open(p,'rb').read()).decode())
html=re.sub(r'src="(a/[^"]+)"',inline,html)
open('index.html','w').write(html)
print(len(html)//1024,'KB')
