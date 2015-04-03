### Deploy Tools  [![Build Status](https://travis-ci.org/kbase/deploy_tools.svg?branch=master)](https://travis-ci.org/kbase/deploy_tools)

This repo contains tools to aid in the deployment of KBase software.  The main script is deploy_cluster.  It reads a config file which is typically named cluster.ini.  The remainder of this readme describes the configuration file.

## Module Parameters

These are parameters used by deploy\_cluster.  These augment the parameters that may be used within the services or by other tools.

- auto-deploy-target - The Makefile target that should be used to deploy this service.
- basedir - The name of the directory the service deploys to under $KB\_TOP/services/.
- deploy - Additional modules to checkout and deploy for the service.  This augments the list in the DEPENDENCIES file in the repo.
- deploy-service - Additional modules to include in the deploy-service stanza of the auto-deploy config file.  Some modules do not deploy all of the clients during a make deploy-client.
- git-branch - Which git branch to deploy from.  Also used for mkhashfile.
- giturl - The URL to the git repo.  This defaults to the service name appended to "repobase" defined in the global section.
- host - The host assigned to run the service.  This will be automatically assigned via mkvm
- proxytype - Used in setup\_www to generate the nginx config file.  Valid options are fastcgi, proxy, or skip.
- skipdeploy - If set then skip deploying this service
- skip-test - Do not run "make test" for this service.
- test-args - Optional test args added to the "make" command.  This overrides the default so you must include the target name (i.e. test)
- type - Type of module.  Should be service or lib.  Lib modules are not assigned to a host.
- urlname - The name used in the URL to access the service (i.e. the urlname would be "ws" for https://kbase.us/services/ws)

## Default Parameters

In general, parameters are initialized to the value defined in a "[defaults]" section and then overridden with the settings for that Section.  Some parameters are rarely overwritten.

- mem - Amount of memory to allocate to the node by default.
- cores - Number of cores to allocate by default.
- baseimage - The vmmaster image to use when cloning the VM in XCAT.
- xcatgroups - The groups to assign the node to in XCAT

## Global Parameters

- basename - Prefix to use in front of alias names for service hosts (i.e. test-invocation)
- baseurl - The base URL for accessing services (i.e. https://kbase.us/ or https://ci.kbase.us)
- deploydir - Target directory for deployment (i.e. /kb/deployment)
- devcontainer - Directory to use for the dev\_container (i.e. /kb/dev\_container)
- disksize - Default disk size for a volume
- docbase - Directory where symlinks to web documentation will be created.
- dtdir - Where the deploy tools should be copied to on remote service hosts.
- hashfile - The filename to store the git hashes.  This is located in the dev container.
- make-options - Default options to include in the make command (i.e. DEPLOY\_RUNTIME=$KB\_RUNTIME ANT\_HOME=$KB\_RUNTIME/ant)
- maxnodes - Maximum number of nodes in a node series that can be allocated. For example, host[01-50] would be maxnodes of 50.
- mem - Memory to allocate to the node.
- repobase - Base URL to use for git repos
- runtime - Location of the runtime.  Deploy\_tools doesn't currently handle building the runtime.
- setup - Default setup script
- xcatgroup - The XCAT group to include all nodes in

## Adding a new service

Here are the steps to add a new service to an existing cluster.

1. Add the stanza to the cluster.ini file.  Be sure to mark the type as service if that is not the default

2. Provision a node using ./deploy\_cluster mkvm.  This should assign a node from the pool if there are available nodes.

3. Boot a node using ./deploy\_cluster boot or just rpower <new node>.  You cannot use the alias name (i.e. test01 not test-idserver).

3a. Run any fix up steps for the node by-hand as root (if needed).  There may be missing dependencies, accounts, mounts, etc that aren't yet included in the base image.  So those must be done out of band.  Generally there should be a fixup.sh script that helps automate this, but it is cluster specific.

4. Regenerate the hash file so that the tag for the new module is captured.  If you want to limit the deploy to just the new service, you may want to generate the new tag file, grep for the new module, then add the line by hand to the active tag file.

5. Sync the deploy and config file with ./deploy\_cluster syncdt

6. Deploy using ./deploy\_cluster deploy all <tag file>

7. Test and redeploy.  If the code doesn't change (no new tag) but you need a redeploy you can use ./deploy\_cluster resetdeploy <hostname>

## Bootstrap

Bootstrap is used to execute commands/scripts that need to run as root.  The following _global_ parameters are important.

- bootstrap-init: This should point to the script that must be run by the Provisioning layer to initalize the system.  It should mainly configure the user account used by DT.
- bootstrap-local: This should point to a directory with local bootstrap files for the cluster being deployed.  This can have very specialized scripts and data such as hosts files, mount options, etc.

A bootstrap will do the following in order...

- Run the local version of bootstrap\_node
- Run the default version of bootstrap\_node (in ./config)
- For each service run
  - the local version of bootstrap\_{service}
  - the default version of bootstrap\_{service} (in ./config)

In general, the default version should handle all of the common cases and the local version is used to specialize the configuration for local needs (i.e. mountpoints)


## TODO

