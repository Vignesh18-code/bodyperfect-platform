#!/usr/bin/env python3
"""Snapshot public BodyPerfect pages into reviewable, source-linked RAG files.
Only explicitly allowed clinic URLs are fetched. No runtime crawling or patient data.
"""
import concurrent.futures, datetime, hashlib, html, json, re, urllib.request
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse
ROOT = Path(__file__).resolve().parents[1]
ORIGIN = 'https://www.bodyperfect.ae'
class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.skip=[]; self.parts=[]; self.links=set(); self.title=[]; self.in_title=False
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if tag=='a' and a.get('href'): self.links.add(urljoin(ORIGIN,a['href']))
        if tag=='title': self.in_title=True
        if tag in ('script','style','nav','header','footer','form','noscript','svg'):
            self.skip.append(tag)
        if not self.skip and tag in ('h1','h2','h3','h4','p','li','br','div'): self.parts.append('\n')
    def handle_endtag(self,tag):
        if tag=='title': self.in_title=False
        if self.skip and tag==self.skip[-1]: self.skip.pop()
        if not self.skip and tag in ('h1','h2','h3','h4','p','li','div'): self.parts.append('\n')
    def handle_data(self,data):
        if self.in_title:self.title.append(data)
        if not self.skip:self.parts.append(data)
def read(url):
    req=urllib.request.Request(url,headers={'User-Agent':'BodyPerfect-Knowledge-Importer/1.0'})
    with urllib.request.urlopen(req,timeout=25) as r:
        if urlparse(r.url).hostname not in ('bodyperfect.ae','www.bodyperfect.ae'): raise ValueError('Off-domain redirect')
        raw=r.read(2_000_000).decode('utf-8','replace')
    p=Page();p.feed(raw)
    # The theme repeats menu text before H1. Keep the actual page content.
    m=re.search(r'<h1\b[^>]*>.*?</h1>',raw,re.S|re.I)
    if m:
        p2=Page();p2.feed(raw[m.start():]);p.parts=p2.parts
    lines=[]
    for line in ''.join(p.parts).splitlines():
        line=re.sub(r'\s+',' ',html.unescape(line)).strip()
        if line in ('Useful Links','Copyright ©','Skip to content'): continue
        if line and (not lines or line!=lines[-1]): lines.append(line)
    text='\n'.join(lines)
    # Remove common footer and enquiry form boilerplate when outside semantic tags.
    for marker in ('\nUseful Links\n','\nAll rights reserved','\nCopyright ©'):
        text=text.split(marker)[0]
    title=html.unescape(''.join(p.title)).strip().split(' - Body Perfect')[0]
    return title,text,p.links

def allowed(u):
    p=urlparse(u)
    return p.scheme=='https' and p.hostname=='www.bodyperfect.ae' and not p.query and not p.fragment and p.path not in ('/appointment','/blog','/success-stories','/offers')
def main():
    _,_,links=read(ORIGIN+'/services/')
    urls=sorted({u.rstrip('/')+'/' for u in links if allowed(u)} | {ORIGIN+'/contact-us/',ORIGIN+'/about-us/',ORIGIN+'/services/'})
    if len(urls)>90: raise ValueError('Unexpected sitemap expansion; review URLs')
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    docs=[];failures=[]
    def task(url):
        try:return url,read(url),None
        except Exception as e:return url,None,type(e).__name__
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for url,result,error in pool.map(task,urls):
            if error:failures.append({'url':url,'error':error});continue
            title,body,_=result
            if len(body)<100:failures.append({'url':url,'error':'Insufficient content'});continue
            slug=urlparse(url).path.strip('/').replace('/','-') or 'home'
            path=ROOT/'knowledge/bodyperfect/pages'/f'{slug}.md'
            path.write_text(f'# {title}\n\nSource: {url}\nRetrieved: {now}\n\n{body}\n')
            docs.append({'id':slug,'title':title,'url':url,'retrievedAt':now,'sha256':hashlib.sha256(body.encode()).hexdigest(),'text':body})
    if len(docs)<12:raise ValueError('Too few pages; existing index was not replaced')
    output=ROOT/'clinicapp/src/main/resources/knowledge';output.mkdir(exist_ok=True)
    (output/'bodyperfect.json').write_text(json.dumps(docs,ensure_ascii=False,indent=2))
    (ROOT/'knowledge/bodyperfect/manifest.json').write_text(json.dumps({'retrievedAt':now,'pages':len(docs),'sources':[{k:v for k,v in d.items() if k!='text'} for d in docs],'failures':failures},ensure_ascii=False,indent=2))
    print(json.dumps({'pages':len(docs),'failures':failures,'characters':sum(len(d['text']) for d in docs)}))
if __name__=='__main__':main()
