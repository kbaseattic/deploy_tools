
## Module Parameters

These are parameters used by deploy_cluster.  These augment the parameters that may be used within the services or by other tools.

- auto-deploy-target - The Makefile target that should be used to deploy this service.
- basedir - The name of the directory the service deploys to under $KB_TOP/services/.
- deploy - Additional modules to checkout and deploy for the service.  This augments the list in the DEPENDENCIES file in the repo.
- deploy-service - Additional modules to include in the deploy-service stanza of the auto-deploy config file.  Some modules do not deploy all of the clients during a make deploy-client.
- git-branch - Which git branch to deploy from.  Also used for mkhashfile.
- giturl - The URL to the git repo.  This defaults to the service name appended to "repobase" defined in the global section.
- host - The host assigned to run the service.  This will be automatically assigned via mkvm
- proxytype - Used in setup_www to generate the nginx config file.  Valid options are fastcgi, proxy, or skip.
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
- deploydir - Target directory for deployment (i.e. /kb/deployment)
- devcontainer - Directory to use for the dev_container (i.e. /kb/dev_container)
- disksize - Default disk size for a volume
- dtdir - Where the deploy tools should be copied to on remote service hosts.
- hashfile - The filename to store the git hashes.  This is located in the dev container.
- make-options - Default options to include in the make command (i.e. DEPLOY_RUNTIME=$KB_RUNTIME ANT_HOME=$KB_RUNTIME/ant)
- maxnodes - Maximum number of nodes in a node series that can be allocated. For example, host[01-50] would be maxnodes of 50.
- mem - Memory to allocate to the node.
- repobase - Base URL to use for git repos
- runtime - Location of the runtime.  Deploy_tools doesn't currently handle building the runtime.
- setup - Default setup script
- xcatgroup - The XCAT group to include all nodes in

## TODO

Some of the parameters in global should be in defaults and vice versa.