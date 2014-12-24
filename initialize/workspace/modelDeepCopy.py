#!/usr/bin/env python

# general idea:
# provide source ws name and instance
# die if can't connect
# provide target ws name and instance
# create wsname if not exist
# for each object in source, save to target
# for models, try to track down the compound references

# (an alternate version would save objects from files, but i want to use prod
# ws, since that's where changes are likeliest to be made)

# todo: copy over object type (probably needs to be manual for now)

import datetime
import sys
import simplejson
import time
import random
import pprint
import string

import biokbase.workspace.client

pp = pprint.PrettyPrinter(indent=4)

wsLookupCache=dict()

def replace_ws_reference(obj,sourcews,targetws):
# this is for pseudoreferences, where "wsid/objid/ver" is stored but not checked
# (also can be used in true references? not sure)
# todo: modify object with proper references
# look up metadata in sourcewsinstance by wsid/objid/ver, find wsname, objname
# (e.g., 489/6/1 is kbase/default)
# look up metadata in targetws by wsname/objname, find wsid/objid/ver
# (e.g., kbase/default is 6/4/1 in ci.kbase)
# replace wsid/objid/ver in object with target's wsid/objid/ver
# need to make this more efficient with many objects, maybe caching?

    if obj in wsLookupCache:
        print 'from cache: ' + wsLookupCache[obj]
        return wsLookupCache[obj]
    (sourceWsId,sourceObjid,sourceVer) = string.split(obj,'/')
    sourceWsObjInfo = sourcews.get_object_info([{"wsid":sourceWsId,"objid":sourceObjid,"ver":sourceVer}],0)
#    print sourceWsObjInfo[0]
    sourceWsname=sourceWsObjInfo[0][7]
    sourceObjname=sourceWsObjInfo[0][1]
    try:
        targetWsObjInfo = targetws.get_object_info([{"workspace":sourceWsname,"name":sourceObjname}],0)
    except:
        print >> sys.stderr, 'error looking up ' + obj
        return ''
#    print targetWsObjInfo[0]
    targetObj=string.join( ( str(targetWsObjInfo[0][6]),str(targetWsObjInfo[0][0]),str(targetWsObjInfo[0][4]) ),'/')
    print 'from ws: ' + targetObj
    wsLookupCache[obj] = targetObj
    return targetObj

def export_import_object(sourcews,sourceWsName,targetws,targetWsName):

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
        objects=sourcews.get_objects([ { "workspace":sourceWsName,"objid":item[0] } ])
        object=objects[0]['data']
# this can be large
#        pp.pprint (object[0]['data'])


# Ideally, we want to generalize this part to handle any typed object
# For now this section's code must understand the structure of the object

        for key in ['genome_ref','template_ref','biochemistry_ref','mapping_ref']:
            if object.has_key(key):
                print >> sys.stderr, 'looking up ' + key + ' for ' + object[key]
                object[key] = replace_ws_reference(object[key],sourcews,targetws)

# for models: need to handle compound_ref, reaction_ref, feature_refs?, complex_ref this way
# these things are buried inside the objects, so need better info on structure
        # compound_ref not a true ref (yay)
#        for mediaCompound in object[0]['data']['mediacompounds']:
#            objStringList=string.split(mediaCompound['compound_ref'],'/')
#            objString=string.join( ( str(objStringList[0]),str(objStringList[1]),str(objStringList[2]) ),'/')
#            targetObjString=replace_ws_reference(objString,sourcews,targetws)
#            if targetObjString != '':
#                mediaCompound['compound_ref'] = string.replace(mediaCompound['compound_ref'],objString,targetObjString)
#            else:
#                print >> sys.stderr, 'reference for ' + objString + ' not found'

        try:
            targetws.save_objects( { "workspace":targetWsName, "objects": [ {"type":item[2], "name": item[1], "data": object } ] } )
        except biokbase.workspace.client.ServerError, e:
            print >> sys.stderr, e
            return

        # debugging: just do one object
        #return

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Copy objects from one workspace to another (can sometimes chase references)')
    parser.add_argument('--source-wsinstance', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--source-wsname', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--target-wsinstance', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--target-wsname', nargs=1, help='workspace name to use', required=True)
    parser.add_argument('--debug',action='store_true',help='debugging')

    args = parser.parse_args()

#    if args.skip_existing:
#        skipExistingGenomes = True

#    print args.source_wsinstance
# in the future might be able to support a list for wsnames
# for now just do one
    sourcews = biokbase.workspace.client.Workspace(args.source_wsinstance[0])
    sourceWsName = args.source_wsname[0]
    targetws = biokbase.workspace.client.Workspace(args.target_wsinstance[0])
    targetWsName = args.target_wsname[0]

    export_import_object(sourcews,sourceWsName,targetws,targetWsName)
