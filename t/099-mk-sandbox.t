use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Server::Control;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
for $ts.server-range -> $server-number {
  ok $ts.server-control.start-mongod("s$server-number"),
     "Server $server-number started";
}

#-------------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE stop");
done-testing();
exit(0);
