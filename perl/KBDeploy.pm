package KBDeploy;

use strict;
use warnings;
use Config::IniFiles;
use Data::Dumper;
use FindBin;

use Carp;
use Exporter;

$KBDeploy::VERSION = "1.0";

use vars  qw(@ISA @EXPORT_OK);
use base qw(Exporter);

our @ISA    = qw(Exporter);
our @EXPORT = qw(read_config mysystem deploy_devcontainer start_service stop_service deploy_service myservices mkdocs);

our $cfg;
$cfg->{global}->{type}='global';
$cfg->{defaults}->{type}='defaults';
our $global=$cfg->{global};
our $defaults=$cfg->{defaults};

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
  die "Unable to find config file\n";
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

# Defaults and paths
#my $KB_DC="$KB_BASE/dev_container";
#my $KB_RT="$KB_BASE/runtime";
#my $MAKE_OPTIONS=$ENV{"MAKE_OPTIONS"};
#
#$KB_DEPLOY=$global->{deploydir} if (defined $global->{deploydir});
#$KB_DC=$global->{devcontainer} if (defined $global->{devcontainer});
#$KB_RT=$global->{runtime} if (defined $global->{runtime});

if (-e "$basedir/config/gitssh" ){
  $ENV{'GIT_SSH'}=$basedir."/config/gitssh";
}

sub maprepos {
  for my $s (keys %{$cfg->{services}}){
  #
    $repo{$s}=$cfg->{services}->{$s}->{giturl};
    die "Undefined giturl for $s" unless defined $repo{$s};
    my $reponame=$repo{$s};
    $reponame=~s/.*\///;
    # Provide the name for the both the service name and repo name
    $repo{$reponame}=$repo{$s};
    $reponame{$s}=$reponame;
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
    $l{$h}=1 if defined $h;
  }
  return join ',',sort keys %l;
}


sub read_config {
   my $file=shift;

   $cfgfile=$file if defined $file;

   my $mcfg=new Config::IniFiles( -file => $cfgfile) or die "Unable to open $file".$Config::IniFiles::errors[0];
   $cfg->{global}->{repobase}='undefined';

   # Read global and default first
   for my $section ('global','defaults'){
       foreach ($mcfg->Parameters($section)){
         $cfg->{$section}->{$_}=$mcfg->val($section,$_);
       }
   }
   # Could use the tie option, but let's build it up ourselves
   
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
sub clonetag {
  my $package=shift;
  my $mytag=$cfg->{services}->{$reponame2service{$package}}->{hash};

  $mytag="head" if ! defined $mytag; 
  $mytag=$global->{tag} if defined $global->{tag};
  print "$package $mytag\n";

  print "- Cloning $package\n";
  my $dir=$repo{$package};
  $dir=~s/\/$//;
  $dir=~s/.*\///;
  if ( -e $dir ) {
    chdir $dir or die "Unable to cd to $dir";
    # Make sure we are on head
    mysystem("git checkout master  > /dev/null 2>&1");
    mysystem("git pull  > /dev/null 2>&1");
    chdir("../");
  }
  else {
    mysystem("git clone $repo{$package} > /dev/null 2>&1");
  }
  if ( $mytag ne "head" ) {
    chdir $package;
    mysystem("git checkout \"$mytag\" > /dev/null 2>&1");
    chdir "../";
  }
  # Save the stats
  my $hash=`cd $dir;git log --pretty='%H' -n 1` or die "Unable to get hash\n";
  chomp $hash;
  my $hf=$global->{devcontainer}."/".$global->{hashfile};
  open GH,">> $hf" or die "Unable to create $hf\n";
  print GH "$reponame2service{$package} $repo{$package} $hash\n";
  close GH;
}

# Recursively get dependencies
#
sub getdeps {
  my $mserv=shift;
  my $KB_DC=$global->{devcontainer};
  print "- Processing dependencies for $mserv\n";
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

  for my $pack ("kbapi_common","typecomp","jars","auth" ) {
    clonetag $pack;
  }
  chdir("$KB_DC");
  mysystem("./bootstrap $KB_RT");

  # Fix up setup
  mysystem("$basedir/config/fixup_dc");

  print "Running Make in dev_container\n";
  mysystem(". ./user-env.sh;make $MAKE_OPTIONS >> $LOGFILE");

  print "Running make deploy\n";
  mysystem(". ./user-env.sh;make deploy $MAKE_OPTIONS >> $LOGFILE");
  print "====\n";
}

# Start service helper function
#
sub start_service {
  my $KB_DEPLOY=$global->{deploydir};
  for my $s (@_)  {
    my $spath=$s;
    $spath=$cfg->{services}->{$s}->{basedir} if (defined $cfg->{services}->{$s}->{basedir});
    if ( -e "$KB_DEPLOY/services/$spath/start_service" ) {
      mysystem(". $KB_DEPLOY/user-env.sh;cd $KB_DEPLOY/services/$spath;./start_service &");
    }
    else {
      print "No start script found in $s\n";
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
      mysystem(". $KB_DEPLOY/user-env.sh;cd $KB_DEPLOY/services/$spath;./stop_service || echo Ignore");
    }
  }
}


# Generate auto deploy
sub generate_autodeploy{
  my $ad=shift;
  my $KB_DC=$global->{devcontainer};

  mysystem("cp $cfgfile $ad");

  # TODO: Remove the need to read in bootstrap.cfg
  my $bcfg=new Config::IniFiles( -file => $KB_DC."/bootstrap.cfg") or die "Unable to open bootstrap".$Config::IniFiles::errors[0];

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
  }
  $acfg->newval($section,'deploy-master',join ',',@{$dlist->{deploy}}) or die "Unable to set deploy-service";
  $acfg->newval($section,'deploy-service',join ',',@{$dlist->{'deploy-service'}}) or die "Unable to set deploy-service";
  $acfg->newval($section,'ant-home',$global->{runtime}."/ant") or die "Unable to set ant-home";

  # Workaround since auth doesn't have a deploy-client target
  my $dc=$bcfg->val($section,'deploy-client');
  $dc=~s/auth,//;
  $acfg->newval($section,'deploy-client',$dc) or die "Unable to set deploy-client";


  $acfg->WriteConfig($ad) or die "Unable to write $ad";
  return 1;
}

sub prepare_service {
  my $LOGFILE=shift;
  my $KB_DC=shift;

  chdir "$KB_DC/modules";
  for my $mserv (@_) {
    print "Deploying $mserv\n";
    # Clone or update the module
    clonetag $mserv;
    # Now get any dependencies
    getdeps $mserv;
  }
}

sub readhashes {
  my $f=shift;
  open(H,$f);
  while(<H>){
    chomp;
    my ($s,$url,$hash)=split;
    $cfg->{services}->{$s}->{hash}=$hash;
    my $confurl=$cfg->{services}->{$s}->{giturl};
    print STDERR "Warning: different git url for service $s\n" if $confurl ne $url;
    print STDERR "Warning: $confurl vs $url\n" if $confurl ne $url;
    $cfg->{services}->{$s}->{hash}=$hash;
    $cfg->{services}->{$s}->{giturl}=$url;
  }
  close H;
}

sub redeploy_service {
  my $tagfile=shift; 

  die unless -e $tagfile;
  readhashes($tagfile);
# Check hashes

  my $hf=$global->{devcontainer}."/".$global->{hashfile};
  if (! open(H,"$hf")){
    print STDERR "Missing hash file $hf\n";
    return 1;
  }
  while(<H>){
    chomp;
    my ($s,$url,$hash)=split;
    return 1 if $url ne $cfg->{services}->{$s}->{giturl};
    return 1 if ! defined $cfg->{services}->{$s}->{hash};
    return 1 if $hash ne $cfg->{services}->{$s}->{hash};
  }
 
  return 0;
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
  mysystem("rm -rf $KB_DC") if (-e $KB_DC);

  # Empty log file
  unlink $LOGFILE if ( -e $LOGFILE );

  # Create the dev container and some common dependencies
  deploy_devcontainer($LOGFILE) unless ( -e "$KB_DEPLOY/bin/compile_typespec" );

  prepare_service($LOGFILE,$KB_DC,@_);
  chdir("$KB_DC");

  print "Starting bootstrap $KB_DC\n";
  mysystem("./bootstrap $KB_RT");

  print "Running make\n";
  mysystem(". $KB_DC/user-env.sh;make $MAKE_OPTIONS >> $LOGFILE 2>&1");

  if ( ! -e $KB_DEPLOY ){
    mkdir $KB_DEPLOY or die "Unable to mkkdir $KB_DEPLOY";
  }
  # Copy the deployment config from the reference copy
  my $ad=$KB_DC."/autodeploy.cfg";
  generate_autodeploy($ad);

  print "Running auto deploy\n";
  mysystem(". $KB_DC/user-env.sh;perl auto-deploy $ad >> $LOGFILE 2>&1");
}

sub deploy_service {
  my $LOGFILE="/tmp/deploy.log";
  my $KB_DEPLOY=$global->{deploydir};
  my $KB_DC=$global->{devcontainer};
  my $KB_RT=$global->{runtime};
  my $MAKE_OPTIONS=$global->{'make-options'};
  my $target=shift;

  # Extingush all traces of previous deployments
  my $d=`date +%s`;
  chomp $d;
  rename($KB_DEPLOY,"$KB_DEPLOY.$d") if -e $KB_DEPLOY;
  mysystem("rm -rf $KB_DC") if (-e $KB_DC);

  # Empty log file
  unlink $LOGFILE if ( -e $LOGFILE );

  # Create the dev container and some common dependencies
  deploy_devcontainer($LOGFILE) unless ( -e "$KB_DEPLOY/bin/compile_typespec" );

  prepare_service($LOGFILE,$KB_DC,@_);
  chdir("$KB_DC");

  print "Starting bootstrap $KB_DC\n";
  mysystem("./bootstrap $KB_RT");
  # Fix up setup
  mysystem("$basedir/config/fixup_dc");

  if ( ! -e $KB_DEPLOY ){
    mkdir $KB_DEPLOY or die "Unable to mkkdir $KB_DEPLOY";
  }
  # Copy the deployment config from the reference copy
  mysystem("cp $cfgfile $KB_DEPLOY/deployment.cfg");

  print "Running make\n";
  mysystem(". $KB_DC/user-env.sh;make $MAKE_OPTIONS >> $LOGFILE 2>&1");

  return if $target eq '';
  print "Running make $target\n";
  mysystem(". $KB_DC/user-env.sh;make $target $MAKE_OPTIONS >> $LOGFILE 2>&1");

}

sub gittag {
  my $service=shift;
  
  my $repo=$repo{$service};
  my $tag=`git ls-remote $repo HEAD`;
  chomp $tag;
  $tag=~s/\tHEAD//;
  return $tag;
}

sub mkdocs {
  my $KB_DEPLOY=$global->{deploydir};
  for my $s (@_){
    my $bd=$cfg->{services}->{$s}->{basedir};
    symlink $KB_DEPLOY."/services/$bd/webroot","/var/www/$bd";
  } 
}


1;
