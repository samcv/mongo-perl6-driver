#`{{
  Testing;
    collection.group()                  Group records
}}

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

use v6;
use Test;
use MongoDB;

#-------------------------------------------------------------------------------
my MongoDB::Connection $connection .= new();
my MongoDB::Database $database = $connection.database('test');

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');

for ^100 -> $c {
  $collection.insert( %( name => 'k' ~ Int(6.rand), value => Int($c.rand)));
}

#show-documents( $collection, {});

# Javascript reduce fnction. If prev[name] is undefined it cannot be set to
# the initial document because these values stay .
#
my $reduce-func = q:to/EOJS/;
function( doc, prev) {
  prev.value = prev.value + doc.value;
  prev.count = prev.count + 1;
}
EOJS

#my $key-func = q:to/EOJS/;
#function(x) {
#  return {x: true};
#}
#EOJS

# Run de grouping function using the javascript reduce function and return
# all results in $r-doc. The results from reduce are found in the field retval.
#
my $result = $collection.group( :js_reduce_func($reduce-func),
                                :initial(%( value => 0, count => 0)),
                                :condition(%(name => %('$gt' => 'k0'))),
                                :key('name'),
#                                :key_js_func($key-func)
                              );
#say "\nR:  {$result.perl}\n";

# Now do the same in perl by getting the docs and do the work of $reduce
#
my %v;
my MongoDB::Cursor $cursor = $collection.find;
while $cursor.next -> %doc {

  # Condition skips all names below k1
  #
  next unless %doc<name> gt 'k0';

  # Change name of key as in the key javascript function
  #
#  %doc<name> = 'long_' ~ %doc<name>;

  if %v{%doc<name>}:!exists {
    %v{%doc<name>}<value> = 0;
    %v{%doc<name>}<count> = 0;
  }

  %v{%doc<name>}<value> += %doc<value>;
  %v{%doc<name>}<count>++;
}

# Compare the results
#
my $r = $result<retval>;
#say "\nA: {$r.perl}\n";
loop ( my $i = 0; $i < +$r; $i++) {
  my $r-doc = $r[$i];
#say "\nL: {$r-doc.perl}\n";
  my $k = $r-doc<name>;
  ok %v{$k}:exists, "V $k exists";
  is $r-doc<value>, %v{$k}<value>, "Value %v{$k}<value>";
  is $r-doc<count>, %v{$k}<count>, "Value %v{$k}<count>";
}

#-----------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done();
exit(0);
