#!/usr/bin/env python

# general idea:
# provide source ws name and instance
# die if can't connect
# provide target ws name and instance
# create wsname if not exist
# for each object in source, save to target

# (an alternate version would save objects from files, but i want to use prod
# ws, since that's where changes are likeliest to be made)

# todo: copy over object type (probably needs to be manual for now)

import datetime
import sys
import simplejson
import time
import random
import pprint

import biokbase.workspace.client

pp = pprint.PrettyPrinter(indent=4)

def shallow_copy(sourcews,sourceWsName,targetws,targetWsName):

# would like to get desc from sourceWsName
    try:
        retval=targetws.create_workspace({"workspace":targetWsName,"globalread":"r","description":"Target workspace"})
        print >> sys.stderr, 'created workspace ' + targetWsName + ' at ws url ' + targetws.url
        print >> sys.stderr, retval
    # want this to catch only workspace exists errors
    except biokbase.workspace.client.ServerError, e:
        print >> sys.stderr, 'workspace ' + targetWsName + ' at ws url ' + targetws.url + ' may already exist, trying to use'

    objects_list = list()
    object_count = 1
    skipNum = 0
    limitNum = 5000
    while object_count != 0:
        this_list = sourcews.list_objects({"workspaces": [sourceWsName],"limit":limitNum,"skip":skipNum})
        object_count=len(this_list)
        skipNum += limitNum
        objects_list.extend(this_list)

    for item in objects_list:
        print item
        object=sourcews.get_objects([ { "workspace":sourceWsName,"objid":item[0] } ])
        pp.pprint (object[0]['data'])
        try:
            targetws.save_objects( { "workspace":targetWsName, "objects": [ {"type":item[2], "name": item[1], "data": object[0]['data'] } ] } )
        except biokbase.workspace.client.ServerError, e:
            print e

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Copy (shallow, do not chase refs) objects from one workspace to another.')
    parser.add_argument('--source-wsinstance', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--source-wsname', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--target-wsinstance', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--target-wsname', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--debug',action='store_true',help='debugging')

    args = parser.parse_args()

#    if args.skip_existing:
#        skipExistingGenomes = True

    print args.source_wsinstance
# in the future might be able to support a list for wsnames
# for now just do one
    sourcews = biokbase.workspace.client.Workspace(args.source_wsinstance[0])
    sourceWsName = args.source_wsname[0]
    targetws = biokbase.workspace.client.Workspace(args.target_wsinstance[0])
    targetWsName = args.target_wsname[0]

    shallow_copy(sourcews,sourceWsName,targetws,targetWsName)
