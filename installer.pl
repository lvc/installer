#!/usr/bin/perl
###########################################################################
# Installer 0.6
# Install/remove tools and their dependencies
#
# Copyright (C) 2015 Andrey Ponomarenko's ABI Laboratory
#
# Written by Andrey Ponomarenko
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License or the GNU Lesser
# General Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# and the GNU Lesser General Public License along with this program.
# If not, see <http://www.gnu.org/licenses/>.
########################################################################### 
use Getopt::Long;
Getopt::Long::Configure ("posix_default", "no_ignore_case");
use File::Path qw(mkpath rmtree);
use File::Temp qw(tempdir);
use File::Basename qw(basename);
use Cwd qw(cwd);

my $TOOL_VERSION = "0.6";
my $ORIG_DIR = cwd();
my $TMP_DIR = tempdir(CLEANUP=>1);
use strict;

my %DEPS = (
    "abi-tracker"             => ["abi-monitor", "abi-dumper", "abi-compliance-checker", "pkgdiff", "rfcdiff"],
    "abi-monitor"             => ["wget", "ctags"],
    "abi-dumper"              => ["elfutils", "vtable-dumper"],
    "vtable-dumper"           => ["libelf-devel", "libelf"],
    "abi-compliance-checker"  => ["binutils", "ctags"],
    "pkgdiff"                 => ["binutils", "rfcdiff", "diff"],
    "rfcdiff"                 => ["diff", "wdiff", "awk"]
);

my %VER = (
    "abi-tracker"             => "1.4",
    "abi-monitor"             => "1.5",
    "abi-dumper"              => "0.99.12",
    "vtable-dumper"           => "1.1",
    "abi-compliance-checker"  => "1.99.14",
    "pkgdiff"                 => "1.7.0"
);

my %ORDER = (
    "abi-tracker" => 1,
    "abi-monitor" => 2,
    "abi-dumper" => 3,
    "abi-compliance-checker" => 4,
    "pkgdiff" => 5,
    "vtable-dumper" => 6,
    "elfutils" => 7,
    "binutils" => 8,
    "libelf-devel" => 9,
    "libelf" => 10,
    "wget" => 11,
    "ctags" => 12
);

my ($Prefix, $Help, $Install, $Remove);
my $CmdName = basename($0);

my $HELP_MSG = "
NAME:
  Installer of the github.com/lvc project

USAGE: $CmdName [options] [tool name]

EXAMPLE:
  sudo perl $CmdName -install -prefix /usr abi-tracker
  sudo perl $CmdName -remove -prefix /usr abi-tracker

OPTIONS:
  -h|-help
      Print this help.

  -prefix PREFIX
      Install files in PREFIX [/usr/local].

  -install
      Command to install the tool.

  -remove
      Command to remove the tool.
\n";

if(not @ARGV)
{
    print $HELP_MSG;
    exit(0);
}

GetOptions(
    "h|help!" => \$Help,
    "prefix=s" => \$Prefix,
    "install!" => \$Install,
    "remove!" => \$Remove
) or exit(1);

sub getDeps($)
{
    my $Tool = $_[0];
    
    my $Deps = $DEPS{$Tool};
    
    my %CompleteDeps = ();
    
    foreach my $Dep (@{$Deps})
    {
        $CompleteDeps{$Dep} = 1;
        
        if(defined $DEPS{$Dep})
        {
            foreach my $SubDep (getDeps($Dep))
            {
                $CompleteDeps{$SubDep} = 1;
            }
        }
    }
    
    my (@First, @Last) = ();
    
    foreach my $Dep (sort keys(%CompleteDeps))
    {
        if(defined $ORDER{$Dep}) {
            push(@First, $Dep);
        }
        else {
            push(@Last, $Dep);
        }
    }
    
    my @Res = sort {$ORDER{$a}<=>$ORDER{$b}} @First;
    push(@Res, @Last);
    
    return @Res 
}

sub check_Cmd($)
{
    my $Cmd = $_[0];
    return "" if(not $Cmd);
    
    foreach my $Path (sort {length($a)<=>length($b)} split(/:/, $ENV{"PATH"}))
    {
        if(-x $Path."/".$Cmd) {
            return 1;
        }
    }
    return 0;
}

sub scenario()
{
    if($Help)
    {
        print $HELP_MSG;
        exit(0);
    }
    
    if(not $Install and not $Remove)
    {
        print STDERR "ERROR: command is not selected (-install or -remove)\n";
        exit(1);
    }
    
    if(not @ARGV)
    {
        print STDERR "ERROR: please specify tool to install/remove\n";
        exit(1);
    }
    
    my $Target = $ARGV[0];
    
    if(not defined $DEPS{$Target})
    {
        print STDERR "ERROR: unknown tool\n";
        exit(1);
    }
    
    if($Prefix ne "/") {
        $Prefix=~s/[\/]+\Z//g;
    }
    
    if(not $Prefix)
    { # default prefix
        $Prefix = "/usr";
    }
    
    if($Prefix!~/\A\//)
    {
        print STDERR "ERROR: prefix is not absolute path\n";
        exit(1);
    }
    
    if(not -d $Prefix)
    {
        print STDERR "ERROR: you should create prefix directory first\n";
        exit(1);
    }
    
    if(not -w $Prefix)
    {
        print STDERR "ERROR: you should be root\n";
        exit(1);
    }
    
    my @Deps = ($Target, getDeps($Target));
    my %NotInstalled = ();
    
    foreach my $Dep (@Deps)
    {
        if(my $V = $VER{$Dep})
        {
            my $Action = "install";
            
            if($Remove and not $Install)
            {
                $Action = "uninstall";
                
                if(not -x $Prefix."/bin/".$Dep)
                {
                    if($Target eq $Dep) {
                        print "$Dep is not installed\n";
                    }
                    next;
                }
            }
            
            print ucfirst($Action)."ing $Dep $V\n";
            
            my $Url = "https://github.com/lvc/$Dep/archive/$V.tar.gz";
            my $BuildDir = $TMP_DIR."/build";
            
            mkpath($BuildDir);
            chdir($BuildDir);
            
            qx/wget $Url --output-document=archive.tar.gz >\/dev\/null 2>&1/;
            if($?)
            {
                print STDERR "ERROR: failed to download $Dep $V\n";
                chdir($ORIG_DIR);
                exit(1);
            }
            
            qx/tar -xf archive.tar.gz/;
            if($?)
            {
                print STDERR "ERROR: failed to extract $Dep $V\n";
                chdir($ORIG_DIR);
                exit(1);
            }
            chdir($Dep."-".$VER{$Dep});
            
            qx/make $Action prefix="$Prefix" >\/dev\/null 2>&1/;
            if($?)
            {
                print STDERR "ERROR: failed to $Action $Dep $V\n";
                chdir($ORIG_DIR);
                exit(1);
            }
            
            chdir($ORIG_DIR);
            
            rmtree($BuildDir);
        }
        elsif($Install)
        {
            if($Dep eq "elfutils")
            {
                if(not check_Cmd("eu-readelf")) {
                    $NotInstalled{$Dep} = 1;
                }
            }
            elsif($Dep eq "binutils")
            {
                if(not check_Cmd("readelf")) {
                    $NotInstalled{$Dep} = 1;
                }
            }
            elsif($Dep eq "libelf-devel")
            {
                if(not -f "/usr/include/libelf.h") {
                    $NotInstalled{$Dep} = 1;
                }
            }
            elsif($Dep eq "libelf")
            {
                my $Ldconfig = `/sbin/ldconfig -p 2>&1`;
                
                if($Ldconfig!~/libelf\.so/) {
                    $NotInstalled{$Dep} = 1;
                }
            }
            elsif(not check_Cmd($Dep))
            {
                $NotInstalled{$Dep} = 1;
            }
        }
    }
    
    if($Install)
    {
        if(my @ToInstall = keys(%NotInstalled))
        {
            print "\nPlease install also:\n  ".join("\n  ", @ToInstall)."\n\n";
        }
        
        if($Target eq "abi-tracker"
        or $Target eq "abi-monitor")
        {
            print "\nPlease install also necessary tools to build analysed libraries:\n  cmake\n  automake\n  scons\n  gcc\n  g++\n  etc.\n\n";
        }
    }
    
    exit(0);
}

scenario();
