import re, sys, json, urllib.parse, subprocess, html
def search(q, pages=1):
    out=[]
    for p in range(1,pages+1):
        url='https://freesound.org/search/?q=%s&f=license%%3A%%22Creative+Commons+0%%22&page=%d' % (urllib.parse.quote_plus(q), p)
        h=subprocess.run(['curl','-sS','-m','25',url],capture_output=True,text=True).stdout
        for m in re.finditer(r'class="bw-player"(.*?)tabindex', h, re.S):
            b=m.group(1)
            g=lambda k: (re.search(k+r'="([^"]*)"', b) or [None,''])[1]
            out.append({'id':g('data-sound-id'),'user':g('data-username'),'title':html.unescape(g('data-title')),'dur':float(g('data-duration') or 0),'mp3':g('data-mp3').replace('-lq.mp3','-hq.mp3')})
    return out
if __name__=='__main__':
    res={}
    for q in sys.argv[1:]:
        r=search(q)
        res[q]=r
        print('##',q)
        for x in r: print('  %s %6.1fs %-18s %s' % (x['id'],x['dur'],x['user'][:18],x['title'][:70]))
    json.dump(res, open('last_search.json','w'), ensure_ascii=False, indent=1)
