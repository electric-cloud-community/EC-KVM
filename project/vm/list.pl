##########################
# list.pl
##########################
use warnings;
use strict;
use utf8;


my $opts;

$opts->{kvm_state_list} = q{$[kvm_state_list]};

$[/myProject/procedure_helpers/preamble]

$gt->list();
exit($opts->{exitcode});