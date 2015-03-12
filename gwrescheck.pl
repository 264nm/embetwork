#!/usr/bin/perl
##This script is used to calculate the default route
##and populate host files with the correct ip address
##of the gateway. This is particularly useful when
##one interface is configured for multiple possible
##vlans.
##Set as a post-up in /etc/network/interfaces

use Net::Ping;
my $defgate;

##Obtain default routes for vlan1 and vlan<N>
my $route1=`route -n  | /usr/bin/awk \'NR==3 { print \$2 }'`;
my $route2=`route -n  | /usr/bin/awk \'NR==4 { print \$2 }'`;

##Gut out whitespace and newlines just to be safe
if ($route1=~/(\S+)/) { $route1=$1; }
if ($route2=~/(\S+)/) { $route2=$1; }

##Ping both possible default routes and determine which one
##is actually available. Store as $defgate.
$p = Net::Ping->new("icmp");
if( $p->ping($route1, $timeout) ) {
  $defgate = $route1;
  $p->close(); 
}
elsif( $p->ping($route2, $timeout) ) {
  $defgate = $route2;
  $p->close(); 
}
else { 
  print "No Default Route"; 
}

##Open /etc/hosts - load into array
open (FILE, "</etc/hosts")
   or die "Can't open file : $!\n";
@lines = <FILE>;
close (FILE);
##Check to see if gateway hostname is pointing to correct route
for my $line (@lines) {
  unless ($line =~ m/$defgate gw.localdomain gw/ ) {
    #If not correct - subsitute ip address with $defgate
    if ($line =~ m/gw.localdomain gw/) {
      my ($ip) = (split / /, $line)[0];
      $line =~ s/$ip/$defgate/g;
    }
    ## Write changes to file		
    open( FILE, ">/etc/hosts" )
      or die "Can't open file : $!\n" ;
    print FILE @lines;
    close FILE;   
  }  
}
##Same stuff as above except for /etc/resolv.conf
open (FILE, "</etc/resolv.conf")
  or die "Can't open file : $!\n";
@lines = <FILE>;
close (FILE);

for my $line (@lines) {
  unless ($line =~ m/nameserver $defgate/ ) {
    unless ($line =~ m/8.8.8.8/) {
      my ($ip) = (split / /, $line)[1]; 
      $line =~ s/$ip/$defgate \n/g;
    }
  open( FILE, ">/etc/resolv.conf" )
    or die "Can't open file : $!\n" ;
  print FILE @lines;
  close FILE;
  }
}
exit 0 ;
