package KBDeploy;

use strict;
use warnings;
use Config::IniFiles;
use Switch;
use Data::Dumper;

use Carp;
use Exporter;

$KBDeploy::VERSION = "1.0";

use vars  qw(@ISA @EXPORT_OK);
use base qw(Exporter);

our @ISA    = qw(Exporter);
our @EXPORT = qw(read_config mysystem deploy_devcontainer start_service stop_service deploy_service myservices);

our $cfg;
our $globaltag;
our %repo;

# TODO: sometimes the service block name is different than the repo name.  Change this to a function.
our %reponame;
our $LOGFILE="/tmp/deploy.log";
our $basedir="/root/dt";

# Defaults and paths
#my $KB_DC="$KB_BASE/dev_container";
#my $KB_RT="$KB_BASE/runtime";
#my $MAKE_OPTIONS=$ENV{"MAKE_OPTIONS"};
#
#$KB_DEPLOY=$cfg->{$gtag}->{deploydir} if (defined $cfg->{$gtag}->{deploydir});
#$KB_DC=$cfg->{$gtag}->{devcontainer} if (defined $cfg->{$gtag}->{devcontainer});
#$KB_RT=$cfg->{$gtag}->{runtime} if (defined $cfg->{$gtag}->{runtime});


$ENV{'GIT_SSH'}="/root/dt/config/gitssh";

sub maprepos {
  for my $s (keys %{$cfg->{services}}){
  #
    $repo{$s}=$cfg->{$globaltag}->{repobase}."/".$s;
    if (defined $cfg->{services}->{$s}->{giturl}){
        $repo{$s}=$cfg->{services}->{$s}->{giturl};
    }
    my $reponame=$repo{$s};
    $reponame=~s/.*\///;
    # Provide the name for the both the service name and repo name
    $repo{$reponame}=$repo{$s};
    $reponame{$s}=$reponame;
  }
}

sub myservices {
  my $me=shift;
  my @sl;
  for my $s (keys %{$cfg->{services}}){
    next unless defined $cfg->{services}->{$s}->{host};
    push @sl,$s if ($cfg->{services}->{$s}->{host} eq $me);
  }
  return @sl;
}


sub read_config {
   my $file=shift;
   $globaltag=shift;
   my $mcfg=new Config::IniFiles( -file => $file) or die "Unable to open $file".$Config::IniFiles::errors[0];

   # Could use the tie option, but let's build it up ourselves

   for my $section ($mcfg->Sections()){
     if ($section eq $globaltag){
       foreach ($mcfg->Parameters($section)){
         $cfg->{$globaltag}->{$_}=$mcfg->val($section,$_);
       }
     }
     else {
       $cfg->{services}->{$section}->{mem}=$cfg->{$globaltag}->{mem};
       $cfg->{services}->{$section}->{cores}=$cfg->{$globaltag}->{cores};
       #$cfg->{services}->{$section}->{host}=$cfg->{$globaltag}->{basename}."-".$section;
       foreach ($mcfg->Parameters($section)){
         $cfg->{services}->{$section}->{$_}=$mcfg->val($section,$_);
       }
       if (! defined $cfg->{services}->{$section}->{type} || $cfg->{services}->{$section}->{type} ne 'lib'){
         push @{$cfg->{servicelist}},$section;
       }
     }
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
  my $mytag=shift;

  $mytag="head" if ! defined $mytag; 
  $mytag=$cfg->{$globaltag}->{tag} if defined $cfg->{$globaltag}->{tag};
  print "$package $mytag\n";

  print "- Cloning $package\n";
  if ( -e $package ) {
    chdir $package;
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
}

# Recursively get dependencies
#
sub getdeps {
  my $mserv=shift;
  my $KB_DC=$cfg->{$globaltag}->{devcontainer};
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
  my $KB_DC=$cfg->{$globaltag}->{devcontainer};
  my $KB_RT=$cfg->{$globaltag}->{runtime};
  my $MAKE_OPTIONS="";

  my $KB_BASE=$KB_DC;
  # Strip off last
  $KB_BASE=~s/.dev_container//;
  mkdir $KB_BASE;
  chdir $KB_BASE;
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
  my $KB_DEPLOY=$cfg->{$globaltag}->{deploydir};
  for my $s (@_)  {
    my $spath=$s;
    $spath=$cfg->{services}->{$s}->{basedir} if (defined $cfg->{services}->{$s}->{basedir});
    if ( -e "$KB_DEPLOY/services/$spath/start_service" ) {
      mysystem(". $KB_DEPLOY/user-env.sh;$KB_DEPLOY/services/$spath/start_service");
    }
    else {
      print "No start script found in $s\n";
    }
  }
}


# Stop Services
#
sub stop_service {
  my $KB_DEPLOY=$cfg->{$globaltag}->{deploydir};
  for my $s (@_) {
    my $spath=$s;
    $spath=$cfg->{services}->{$s}->{basedir} if defined $cfg->{services}->{$s}->{basedir};
    if ( -e "$KB_DEPLOY/services/$spath/stop_service"){
      mysystem(". $KB_DEPLOY/user-env.sh;$KB_DEPLOY/services/$spath/stop_service");
    }
  }
}


sub deploy_service {
  my $KB_DEPLOY=$cfg->{$globaltag}->{deploydir};
  my $KB_DC=$cfg->{$globaltag}->{devcontainer};
  my $KB_RT=$cfg->{$globaltag}->{runtime};

  # Extingush all traces of previous deployments
  my $d=`date +%s`;
  rename($KB_DEPLOY,"$KB_DEPLOY.$d") if -e $KB_DEPLOY;
  mysystem("rm -rf $KB_DC") if (-e $KB_DC);

  # Empty log file
  unlink $LOGFILE if ( -e $LOGFILE );

  # Create the dev container and some common dependencies
  if ( ! -e "$KB_DEPLOY/bin/compile_typespec" ) {
    deploy_devcontainer($LOGFILE);
  }

  chdir "$KB_DC/modules";
  for my $mserv (@_) {
    print "Deploying $mserv\n";
    # Clone or update the module
    clonetag $mserv;
    # Now get any dependencies
    getdeps $mserv;
  }
 
  chdir("$KB_DC");

  print "Starting bootstrap $KB_DC\n";
  mysystem("./bootstrap $KB_RT");
  # Fix up setup
  mysystem("$basedir/config/fixup_dc");

  print "Running make\n";
  mysystem(". $KB_DC/user-env.sh;make >> $LOGFILE 2>&1");

  print "Running make deploy\n";
  mysystem(". $KB_DC/user-env.sh;make deploy >> $LOGFILE 2>&1");

  # Copy the deployment config from the reference copy
  mysystem("cp $basedir/cluster.ini $KB_DEPLOY/deployment.cfg");
}


1;
