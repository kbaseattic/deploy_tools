package KBDeploy;

use strict;
use warnings;
use Config::IniFiles;
use Data::Dumper;
use FindBin;
use POSIX qw(strftime);
use Cwd;

use Carp;
use Exporter;

$KBDeploy::VERSION = "1.0";

use vars  qw(@ISA @EXPORT_OK);
use base qw(Exporter);

our @ISA    = qw(Exporter);
our @EXPORT = qw(read_config mysystem deploy_devcontainer start_service stop_service myservices mkdocs);

our $logfh;
our $loglevel=0;
our $cfg;
our $global; #=$cfg->{global};
our $defaults; #=$cfg->{defaults};

our $cfgfile;

# Order of search: Look in run directory, then directory of script, then one level up
if ( -e './cluster.ini'){
  $cfgfile="./cluster.ini";
}
elsif ( -e $FindBin::Bin.'/cluster.ini'){
  $cfgfile=$FindBin::Bin.'/cluster.ini';
}
elsif ( -e $FindBin::Bin.'/../cluster.ini'){
  $cfgfile=$FindBin::Bin.'/../cluster.ini';
}
else {
  $cfgfile="unknown";
  warn "Unable to find config file\n";
}


# repo is hash that points to the git repo.  It should work for both the
# service name in the config file as well as the git repo name
our %repo;
# This makes it easy to map from a git repo name to a service
# i.e.  user_and_job_state -> UserAndJobState
our %reponame2service;

# TODO: sometimes the service block name is different than the repo name.  Change this to a function.
our %reponame;
our $basedir=$FindBin::Bin;
$basedir=~s/config$//;

# TODO: Move this
if (-e "$basedir/config/gitssh" ){
  $ENV{'GIT_SSH'}=$basedir."/config/gitssh";
}

sub setlog {
  $logfh=shift; 
}

sub setloglevel {
  $loglevel=shift; 
}

sub kblog {
  my $line=shift;
  my $level=shift;
  setlog(*STDOUT) if ! defined $logfh;

  print $logfh $line;
}

sub maprepos {
  undef %repo;
  undef %reponame;
  undef %reponame2service;
  for my $s (keys %{$cfg->{services}}){
  #
    $repo{$s}=$cfg->{services}->{$s}->{giturl};
    die "Undefined giturl for $s" unless defined $repo{$s};
    my $reponame=$repo{$s};
    $reponame=~s/.*\///;
    # Provide the name for the both the service name and repo name
    $repo{$reponame}=$repo{$s};
    $reponame{$s}=$reponame;
    $reponame{$reponame}=$reponame;
    $reponame2service{$reponame}=$s;
    $reponame2service{$s}=$s;
  }
}

sub myservices {
  my $me=shift;
  if (! defined $me || $me eq ''){
    $me=`hostname`;
    chomp $me;
  }
  my @sl;
  for my $s (@{$cfg->{servicelist}}){
    next unless defined $cfg->{services}->{$s}->{host};
    push @sl,$s if ($cfg->{services}->{$s}->{host} eq $me);
  }
  return @sl;
}

sub hostlist {
  my %l;
  for my $s (keys %{$cfg->{services}}){
    my $h=$cfg->{services}->{$s}->{host};
    next if defined $cfg->{services}->{$s}->{skipdeploy};
    $l{$h}=1 if defined $h;
  }
  return join ',',sort keys %l;
}


sub read_config {
   my $file=shift;

   $cfgfile=$file if defined $file;

   my $mcfg=new Config::IniFiles( -file => $cfgfile) or die "Unable to open $file".$Config::IniFiles::errors[0];

   # Reset things
   undef $cfg;
   $cfg->{global}->{type}='global';
   $cfg->{defaults}->{type}='defaults';
   $global=$cfg->{global};
   $defaults=$cfg->{defaults};
   $global->{repobase}="undefined";
   $global->{basename}="bogus";
   $global->{hashfile}="githashes";
   $global->{runtime}="/usr";
   $global->{'make-options'}="";
   $global->{'default-modules'}="kbapi_common,typecomp,jars,auth";
   $defaults->{'setup'}='setup_service';
   $defaults->{'auto-deploy-target'}='deploy';
   $defaults->{'git-branch'}='master';
   $defaults->{'test-args'}='test';

   # Read global and default first
   for my $section ('global','defaults'){
       foreach ($mcfg->Parameters($section)){
         $cfg->{$section}->{$_}=$mcfg->val($section,$_);
       }
   }
   # Trim off trailing slash to avoid bogus mismatches
   $global->{repobase}=~s/\/$//;
   
   
   for my $section ($mcfg->Sections()){
     next if ($section eq 'global' || $section eq 'defaults');
     # Populate default values
     for my $p (keys %{$defaults}){
       $cfg->{services}->{$section}->{$p}=$defaults->{$p};
     }
     $cfg->{services}->{$section}->{urlname}=$section;
     $cfg->{services}->{$section}->{basedir}=$section;
     $cfg->{services}->{$section}->{alias}=$global->{basename}.'-'.$section;
     $cfg->{services}->{$section}->{giturl}=$global->{repobase}."/".$section;

     # Now override or add with defined values
     foreach ($mcfg->Parameters($section)){
       $cfg->{services}->{$section}->{$_}=$mcfg->val($section,$_);
     }
     $cfg->{services}->{$section}->{giturl}=cleanup_url($cfg->{services}->{$section}->{giturl});
     push @{$cfg->{servicelist}},$section if ( $cfg->{services}->{$section}->{type} eq 'service');
   }
   maprepos();
   return $cfg;
}

sub update_config {
   my $file=shift;
   my $section=shift;
   my $param=shift;
   my $value=shift;

   my $mcfg=new Config::IniFiles( -file => $file) or die "Unable to open $file".$Config::IniFiles::errors[0];

   if ( ! defined $mcfg->val($section,$param)){
     $mcfg->newval($section,$param,$value);
   }
   $mcfg->WriteConfig($file);
}


sub mysystem {
  foreach (@_){
    system($_) eq 0 or die "Failed on $_ in $0\n";
  }
}

# Helper function to clone a module and checkout a tag.
# Also records the tag that was cloned or checked out
sub clonetag {
  my $package=shift;
  # get the service name (which may be different than the package name
  my $serv=$package;
  $serv=$reponame2service{$package};# if ! defined $serv;
  # Workaround.  Need to restructure where hash/URLs are stored
  #
  if (! defined $cfg->{services}->{$serv}->{hash} && 
        defined $cfg->{services}->{$package}->{hash}){
    $serv=$package;
  }
  my $repo=$repo{$package};
  die "no repo defined for $package!" unless $repo;
  my $mytag=$cfg->{services}->{$serv}->{hash};
  my $mybranch=$cfg->{services}->{$serv}->{'git-branch'};

  $mytag="head" if ! defined $mytag; 
  $mybranch="master" if ! defined $mybranch; 
  $mytag=$global->{tag} if defined $global->{tag};
  kblog "  - Cloning $package (tag: $mytag branch:$mybranch)\n";
  my $rname=$reponame{$package};
  my $dir=$rname;

  # If the directory exist and matches our tag, then we are happy 
  if ( -e $dir && defined $cfg->{deployed}->{$rname}){
    kblog "Checking state\n";
    # Return if the versions are the same
    return if $cfg->{deployed}->{$rname}->{hash} eq $mytag;
    kblog "Deployed version is different.\n";
  }
  else {
    mysystem("git clone --recursive $repo > /dev/null 2>&1");
    #chdir $dir or die "Unable to chdir";
    #mysystem("git checkout $mybranch > /dev/null 2>&1");
    #chdir "../";
  }

  if ( $mytag ne "head" ) {
    chdir $dir or die "Unable to chdir";
    mysystem("git checkout \"$mytag\" > /dev/null 2>&1");
    chdir "../";
  }
  elsif ( $mybranch ne "master" ) {
    chdir $dir or die "Unable to chdir";
    mysystem("git checkout \"$mybranch\" > /dev/null 2>&1");
    chdir "../";
  }
  # Save the stats
  my $hash=`cd $dir;git log --pretty='%H' -n 1` or die "Unable to get hash\n";
  chomp $hash;
  die "hash doesn't match expected value $hash vs $mytag" if ($hash ne $mytag && $mytag ne 'head');
  # This will get writen into a hash file
  $cfg->{deployed}->{$rname}->{hash}=$hash;
  $cfg->{deployed}->{$rname}->{repo}=$repo;
}

# Write out githash
sub write_githash {
  my $hf=shift;
  open GH,'>'.$hf or die "Unable to create $hf\n";
  foreach my $serv (keys %{$cfg->{deployed}}){
    my $dep=$cfg->{deployed}->{$serv};
    printf GH "%s %s %s\n",$serv,$dep->{repo},$dep->{hash};
  }
  print GH "Done\n";
  close GH;
}

# Read githash
sub read_githash {
  my $hf=shift; 

  if (! open(H,"$hf")){
    kblog "No hash file $hf\n";
    return 1;
  }

  while(<H>){
    return 0 if /Done/;
    my ($serv,$repo,$hash)=split;
    $repo=cleanup_url($repo);
    $cfg->{deployed}->{$serv}->{hash}=$hash;
    $cfg->{deployed}->{$serv}->{repo}=$repo;
  }
  # Not sure about this
  delete $cfg->{deployed};
  return 1;
}

# Recursively get dependencies
#
sub getdeps {
  my $mserv=shift;
  my $KB_DC=$global->{devcontainer};
  kblog "  - Processing dependencies for $mserv\n";
  $mserv=$reponame{$mserv} if defined $reponame{$mserv};

  my $DEP="$KB_DC/modules/$mserv/DEPENDENCIES";
  return if ( ! -e "$DEP" );

  my @deps;
  open(D,$DEP) or die "Unable to open $DEP";
  while (<D>){
    chomp;
    push @deps,$_;
  }
  close D;

  foreach $_ (@deps){
    if ( ! -e "$KB_DC/modules/$_" ) {
      clonetag($_);
      getdeps($_);
    }
  }
}

# Deploy the Dev Container
#
sub deploy_devcontainer {
  my $LOGFILE=shift;
  my $KB_DC=$global->{devcontainer};
  my $KB_RT=$global->{runtime};
  my $MAKE_OPTIONS=$global->{'make-options'};

  my $KB_BASE=$KB_DC;
  # Strip off last
  $KB_BASE=~s/.dev_container//;
  if ( ! -e $KB_BASE ){
    mkdir $KB_BASE or die "Unable to mkkdir $KB_BASE";
  }
  chdir $KB_BASE or die "Unable to cd $KB_BASE";
  clonetag "dev_container";
  chdir "dev_container/modules";

  for my $pack (split /,/,$global->{'default-modules'}){
    next if $pack eq '';
    clonetag $pack;
  }
  chdir("$KB_DC");
  mysystem("./bootstrap $KB_RT >> $LOGFILE 2>&1");

  # Fix up setup
  if (-e "$basedir/config/fixup_dc"){
    mysystem("$basedir/config/fixup_dc");
  }

  kblog "Running Make in dev_container\n";
  mysystem(". ./user-env.sh;make $MAKE_OPTIONS >> $LOGFILE 2>&1");

  kblog "Running make deploy\n";
  mysystem(". ./user-env.sh;make deploy $MAKE_OPTIONS >> $LOGFILE 2>&1");
  kblog "====\n";
}

# Start service helper function
#
sub start_service {
  my $KB_DEPLOY=$global->{deploydir};
  for my $s (@_)  {
    my $spath=$s;
    $spath=$cfg->{services}->{$s}->{basedir} if (defined $cfg->{services}->{$s}->{basedir});
    if ( -e "$KB_DEPLOY/services/$spath/start_service" ) {
      kblog "Starting service $s\n";
      mysystem(". $KB_DEPLOY/user-env.sh;cd $KB_DEPLOY/services/$spath;./start_service &");
    }
    else {
      kblog "No start script found in $s\n";
    }
  }
}


# Stop Services
#
sub stop_service {
  my $KB_DEPLOY=$global->{deploydir};
  for my $s (@_) {
    my $spath=$s;
    $spath=$cfg->{services}->{$s}->{basedir} if defined $cfg->{services}->{$s}->{basedir};
    if ( -e "$KB_DEPLOY/services/$spath/stop_service"){
      kblog "Stopping service $s\n";
      mysystem(". $KB_DEPLOY/user-env.sh;cd $KB_DEPLOY/services/$spath;./stop_service || echo Ignore");
# don't care about return value here (really bad style, I know)
      system("pkill -f glassfish");
    }
  }
}

sub test_service {
  my $LOGFILE="/tmp/test.log";
  my $KB_DC=$global->{devcontainer};
  for my $s (@_)  {
    if (defined $cfg->{services}->{$s}->{'skip-test'} && $cfg->{services}->{$s}->{'skip-test'} == 1) {
        kblog "skipping tests for $s";
        return;
    }
    kblog "running tests for $s";

    my $spath=$s;
# need the git checkout dir name here
    my $giturl=$cfg->{services}->{$s}->{giturl} if (defined $cfg->{services}->{$s}->{giturl});
    ($spath)=$giturl=~/.*\/(.+)$/ if ($giturl);
    if ( -e "$KB_DC/modules/$spath" ) {
      kblog "Testing service $s\n";
      # not sure why it's not picking up DEPLOY_RUNTIME
      # need to fix this at some point, but not essential right now
      my $TEST_ARGS=$cfg->{services}->{$s}->{'test-args'};
      mysystem(". $KB_DC/user-env.sh;cd $KB_DC/modules/$spath;DEPLOY_RUNTIME=\$KB_RUNTIME make $TEST_ARGS ; echo 'done with tests'");
#      mysystem(". $KB_DC/user-env.sh;cd $KB_DC/modules/$spath;DEPLOY_RUNTIME=\$KB_RUNTIME make $TEST_ARGS &> $LOGFILE ; echo 'done with tests'");
    }
    else {
      kblog "No dev directory found in $s\n";
    }
  }
}


# Generate auto deploy
sub generate_autodeploy{
  my $ad=shift;
  # this will be an arrayref
  my $override_dc=shift;
  my $KB_DC=$global->{devcontainer};

  mysystem("cp $cfgfile $ad");

  # TODO: Remove the need to read in bootstrap.cfg
#  my $bcfg=new Config::IniFiles( -file => $KB_DC."/bootstrap.cfg") or die "Unable to open bootstrap".$Config::IniFiles::errors[0];

  # Fix up config
  my $acfg=new Config::IniFiles( -file => $ad) or die "Unable to open $ad".$Config::IniFiles::errors[0];

  my $section='default';
  $acfg->newval($section,'target',$global->{deploydir}) or die "Unable to set target";
  $acfg->newval($section,'deploy-runtime',$global->{runtime}) or die "Unable to set runtime";
  my $dlist;
  $dlist->{'deploy'}=[];
  $dlist->{'deploy-service'}=[];
  for my $s (myservices()){
    my $dt=$cfg->{services}->{$s}->{'auto-deploy-target'};
    push @{$dlist->{$dt}},$reponame{$s}; 
    if (defined $cfg->{services}->{$s}->{'deploy-service'}){
       push @{$dlist->{'deploy-service'}},split /,/,$cfg->{services}->{$s}->{'deploy-service'};
    }
    if (defined $cfg->{services}->{$s}->{'deploy-master'}){
       push @{$dlist->{'deploy'}},split /,/,$cfg->{services}->{$s}->{'deploy-master'};
    }
  }
  
  $acfg->newval($section,'deploy-master',join ',',@{$dlist->{deploy}}) or die "Unable to set deploy-service";
  $acfg->newval($section,'deploy-service',join ',',@{$dlist->{'deploy-service'}}) or die "Unable to set deploy-service";
  $acfg->newval($section,'ant-home',$global->{runtime}."/ant") or die "Unable to set ant-home";

  # new: read directory listing and deploy those clients
  my $module_dir=$KB_DC.'/modules/';
  opendir MODULEDIR,$module_dir || die "couldn't open $module_dir: $!";
  my @dc;
#   skip these names
  my @skip=('..','.');
  if (defined $cfg->{global}->{'skip-deploy-client'}){
    push @skip,split /,/,$cfg->{global}->{'skip-deploy-client'};
  }
  my %skip=map {$_=>1} @skip;
  while (my $module=readdir(MODULEDIR))
  {
    next if $skip{$module};

    next unless (-d $module_dir.'/'.$module);

    push @dc,$module;
  }
  closedir MODULEDIR;

#  $acfg->newval($section,'deploy-client',$module) or die "Unable to set deploy-client";
  my $dc=join ', ',sort @dc;
  if (ref $override_dc and scalar @{$override_dc} > 0)
  {
    $dc=join ', ', @{$override_dc};
  }
  $acfg->newval($section,'deploy-client',$dc) or die "Unable to set deploy-client";

  $acfg->WriteConfig($ad) or die "Unable to write $ad";
  return 1;
}

sub prepare_service {
  my $LOGFILE=shift;
  my $KB_DC=shift;

  chdir "$KB_DC/modules";
  for my $mserv (@_) {
    kblog "Deploying $mserv\n";
    # Clone or update the module
    clonetag $mserv;
    if (defined $cfg->{services}->{$mserv}->{deploy}){
      foreach my $s (split /,/,$cfg->{services}->{$mserv}->{deploy}){
        clonetag $s;
        getdeps $s;
      }
    }
    # Now get any dependencies
    getdeps $mserv;
  }
}

#
# Genereate tag file
#
sub mkhashfile {
  my $tagfile=shift;
  my $ds=strftime "%Y%m%d%H%M", localtime;
  if (! defined $tagfile){
    $tagfile="tagfile.$ds";
  }
  my $out;
  my %hashes;
  for my $service (keys %{$cfg->{services}}){
    my $s=$cfg->{services}->{$service};
    next if $s->{giturl} eq 'none';
    my $tag=KBDeploy::gittag($service);
    my $rname=$reponame{$service};
    if (length $tag eq 0){
      print STDERR "Failed to get tag for $service\n";
      return 0;
    }
    if (defined $hashes{$rname} && $tag ne $hashes{$rname}){
      print STDERR "You have two services that map to the same reponame,\n";
      print STDERR "yet result in different hashes. Please correct.\n";
      print STDERR "Failing mkhashfile.\n";
      return 0;
    }
    $hashes{$rname}=$tag;

    $out.="$service $s->{giturl} $tag\n";
  }
  open TF,"> $tagfile" or die "Unable to create $tagfile\n";
  print TF "# $ds\n";
  print TF $out;
  close TF;
  return 1;
}

#
# Genereate tag file
#
sub updatehashfile {
  my $tagfile=shift;
  my $ds=strftime "%Y%m%d%H%M", localtime;
  my %update;
  map {$update{$_}=1} @_;

  my $out;
  open(TF,$tagfile) or die "Unable to open $tagfile\n";
  while(<TF>){
    next if /^#/;
    chomp;
    my ($service,$url,$tag)=split;
    if (defined $update{$service}){
      kblog "Updating $service\n";
      $url=$cfg->{services}->{$service}->{giturl};
      $tag=KBDeploy::gittag($service);
      print STDERR "Problem with $service\n" unless length($tag)>0;
    }
    $out.="$service $url $tag\n";
  }
  close TF;
  open TF,"> $tagfile" or die "Unable to create $tagfile\n";
  print TF "# $ds\n";
  print TF $out;
  close TF;
}

sub readhashes {
  my $f=shift;
  open(H,$f);
  while(<H>){
    next if /^#/;
    chomp;
    my ($s,$url,$hash)=split;
    $url=cleanup_url($url);
    my $confurl=$cfg->{services}->{$s}->{giturl};
    $confurl="undefined" if ! defined $confurl;
    kblog "Warning: different git url for service $s\n" if $confurl ne $url;
    kblog "Warning: $confurl(config file) vs $url(tag file)\n" if $confurl ne $url;
    $cfg->{services}->{$s}->{hash}=$hash;
    $cfg->{services}->{$s}->{giturl}=$url;
  }
  close H;
}

#
# check_updates
#  Returns status and a list
#  status=1 if redeploy need and 0 if not
#  list is list of services that changed
#
sub check_updates {
  my $tagfile=shift; 

  die "Tagfile $tagfile not found" unless -e $tagfile;
  readhashes($tagfile);

# Check hashes

  my $redeploy=read_githash($global->{devcontainer}."/".$global->{hashfile});
  kblog "No previous deploy or previous deploy was incomplete\n" if ($redeploy);
  my @redeploy_list;
  for my $r (keys %{$cfg->{deployed}}){
    my $repo=$cfg->{deployed}->{$r}->{repo};
    my $hash=$cfg->{deployed}->{$r}->{hash};
    my $s=$r;
    $s=$reponame2service{$r} if ! defined $cfg->{services}->{$s}->{giturl};
    die "Error: couldn't find a matching service for $s\n" if ! defined $cfg->{services}->{$s}->{giturl};
    if ($repo ne $cfg->{services}->{$s}->{giturl}){
      kblog " - Redeploy change in URL for $s\n";
      push @redeploy_list,$s;
      $redeploy=1;
    }
    elsif (! defined $cfg->{services}->{$s}->{hash}){
      kblog " - Redeploy no hash for $s\n";
      push @redeploy_list,$s;
      $redeploy=1;
    }
    elsif ($hash ne $cfg->{services}->{$s}->{hash}){
      kblog " - Redeploy change in hash for $s\n";
      push @redeploy_list,$s;
      $redeploy=1;
    }
  }
 
  # Missing Done flag 
  return ($redeploy,@redeploy_list);
  #return 1;
}

sub auto_deploy {
  my $LOGFILE="/tmp/deploy.log";
  my $KB_DEPLOY=$global->{deploydir};
  my $KB_DC=$global->{devcontainer};
  my $KB_RT=$global->{runtime};
  my $MAKE_OPTIONS=$global->{'make-options'};

  # Extingush all traces of previous deployments
  my $d=`date +%s`;
  chomp $d;
  rename($KB_DEPLOY,"$KB_DEPLOY.$d") if -e $KB_DEPLOY;
  # Cleanup deployed structure
  undef $cfg->{deployed};
  mysystem("rm -rf $KB_DC") if (-e $KB_DC);

  # Empty log file
  unlink $LOGFILE if ( -e $LOGFILE );

  # Create the dev container and some common dependencies
  deploy_devcontainer($LOGFILE) unless ( -e "$KB_DEPLOY/bin/compile_typespec" );

  prepare_service($LOGFILE,$KB_DC,@_);
  chdir("$KB_DC");

  kblog "Starting bootstrap $KB_DC\n";
  mysystem("./bootstrap $KB_RT >> $LOGFILE 2>&1");

  kblog "Running make\n";
  mysystem(". $KB_DC/user-env.sh;make $MAKE_OPTIONS >> $LOGFILE 2>&1");

  if ( ! -e $KB_DEPLOY ){
    mkdir $KB_DEPLOY or die "Unable to mkkdir $KB_DEPLOY";
  }
  # Copy the deployment config from the reference copy
  my $ad=$KB_DC."/autodeploy.cfg";
  generate_autodeploy($ad);

  kblog "Running auto deploy\n";
  mysystem(". $KB_DC/user-env.sh;perl auto-deploy $ad >> $LOGFILE 2>&1");
}

#
# Deploy
#
sub deploy_service {
  my $hashfile=shift;
  my $dryrun=shift;
  my $force=shift;

  my @sl=myservices();
  
  return -1 unless scalar(@sl);

  mkdocs(@sl);
  return -2 if (! defined $hashfile && is_complete(@sl) && $force);
#
# redploy_service will tell us if we need to repeploy but
# it also populates that hashes to deploy
  my ($redeploy,@list)=KBDeploy::check_updates($hashfile,@sl);
  if (! $redeploy && $force==0){
    kblog " - No deploy required for $sl[0]\n";
    return -3;
  }
  if ($dryrun){
    kblog " - Redploy needed.  Exiting with dryrun\n";
    return -4;
  }

  stop_service(@sl);
  auto_deploy(@sl);
  postprocess(@sl);
  start_service(@sl);
  mark_complete(@sl);
  return 0;
}


#
# Update service only redeploys modules that have changed
#
sub update_service {
  my $hashfile=shift;
  my $dryrun=shift;

# Connivence variables
  my $LOGFILE="/tmp/deploy.log";
  my $KB_DEPLOY=$global->{deploydir};
  my $KB_DC=$global->{devcontainer};
  my $KB_RT=$global->{runtime};
  my $MAKE_OPTIONS=$global->{'make-options'};
  my $ad=$KB_DC."/autodeploy.cfg";
  my @sl=myservices();

  return -1 if scalar @sl eq 0;
  kblog "Updating @sl with $hashfile\n"; 
  mkdocs(@sl);
  # TODO: Should we keep this
  return -2 if (! defined $hashfile && KBDeploy::is_complete(@sl));
#
# redploy_service will tell us if we need to repeploy but
# it also populates that hashes to deploy
  my ($reqdep,@redeploy)=check_updates("$hashfile",@sl);
  if ($reqdep==0){
    kblog " - No deploy required for $sl[0]\n";
    return -3;
  }

  if ($dryrun){
    kblog " - Redploy needed.  Exiting with dryrun\n";
    return -4;
  }

  stop_service(@sl);

  # Checkout the right versions
  prepare_service($LOGFILE,$KB_DC,@redeploy);

  # For each service we need to chdir in and do a make
  kblog "  - Running make on updated modules\n";
  foreach my $s (@redeploy){
    my $rname=$reponame{$s};
    chdir $KB_DC."/modules/".$rname;
    mysystem(". $KB_DC/user-env.sh;make $MAKE_OPTIONS >> $LOGFILE 2>&1");
  }
  kblog "  - Running autodeploy\n";
  chdir $KB_DC;
  foreach my $s (@redeploy){
    my $rname=$reponame{$s};
    mysystem(". $KB_DC/user-env.sh;perl auto-deploy --module $rname $ad >> $LOGFILE 2>&1");
  }
  foreach my $s (@sl){
    postprocess($s);
  }

  start_service(@sl);

  mark_complete(@sl);
  return 0;
}

sub postprocess {
  my $LOGFILE="/tmp/deploy.log";
  my $KB_DEPLOY=$global->{deploydir};
  $ENV{'KB_CONFIG'}=$cfgfile;
  for my $serv (@_) {
    if (-e "${FindBin::Bin}/config/postprocess_$serv") {
      kblog "postprocessing service $serv";
      mysystem(". $KB_DEPLOY/user-env.sh; ${FindBin::Bin}/config/postprocess_$serv >> $LOGFILE 2>&1");
    }
  }

}

sub gittag {
  my $service=shift;
  
  my $repo=$repo{$service};
  my $mybranch=$cfg->{services}->{$service}->{'git-branch'};

  $mybranch="master" if ! defined $mybranch; 
  my $tag=`git ls-remote $repo heads/$mybranch`;
  chomp $tag;
  $tag=~s/\t.*//;
  return $tag;
}

sub mkdocs {
  my $KB_DEPLOY=$global->{deploydir};
  my $docbase=$global->{docbase};
  return if ! defined $docbase;
  for my $s (@_){
    my $bd=$cfg->{services}->{$s}->{basedir};
    symlink $KB_DEPLOY."/services/$bd/webroot","$docbase/$bd";
  } 
}

# Use this to mark as service/node as deployed
#  Dirt simple semphor flag for now
# TODO: mark services indvidually
#
sub mark_complete {
  my @services=@_;
  kblog 'Services deployed successfully: ' . join ', ', @services;
  kblog "\n";
  write_githash($global->{devcontainer}."/".$global->{hashfile});
}

# Use this to determine if a node is already finished
#
sub is_complete {
  my @services=@_;
  my $hf=$global->{devcontainer}."/".$global->{hashfile};
  open(H,"$hf") or return 0;
  while (<H>){
    return 1 if /^Done$/;
  }
  return 0;
}

sub reset_complete {
  my $hf=$global->{devcontainer}."/".$global->{hashfile};
  rename $hf,$hf.'.old';
}

# Remove double slashes
#
sub cleanup_url {
  my $url=shift; 
  $url=~s/([^:\/])\/\/([a-zA-Z])/$1\/$2/;
  return $url;
}

1;
