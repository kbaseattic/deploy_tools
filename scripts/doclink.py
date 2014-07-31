#!/usr/bin/env python
#
# Usage: python doclink.py <url>
#
# Prereqs: 
# python v2.6+
# python libs - httplib2, BeautifulSoup
#
# Author: Shreyas Cholia (LBL) 2013/02/11


import httplib2
from BeautifulSoup import BeautifulSoup, SoupStrainer
import sys

if len(sys.argv)==2:
  if sys.argv[1] == 'prod':
    base_url = "http://kbase.us"
  else:
    base_url = sys.argv[1]
  print "Using "+base_url
else:
    base_url = "http://140.221.84.191"
docs_url = base_url + "/services/docs/"

http = httplib2.Http()
status, response = http.request(docs_url)

for link in BeautifulSoup(response, parseOnlyThese=SoupStrainer('a')):
    if link.has_key('href'):
        link_url = docs_url + link['href']
        print "visiting: " + link_url
        h = httplib2.Http()
        st, res = h.request(link_url)
        if int(st.status)!=200:
            print("    %s -> Bad status: %s" % (link['href'], st.status))
        elif len(res)==0:
            print("    %s -> Empty Documentation Page" % link['href'])
        else:
            subdocs = [ s for s in BeautifulSoup(res, parseOnlyThese=SoupStrainer('a')) ]
            if len(subdocs)==1 and subdocs[0]['href']=='../':
                print("    %s -> Empty Index. No Docs found." % link['href'])
    
        
