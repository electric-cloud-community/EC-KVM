##########################
# revert.pl
##########################
use warnings;
use strict;
use utf8;


my $opts;

$opts->{kvm_snapshot_name} = q{$[kvm_snapshot_name]};
$opts->{kvm_vmname} = q{$[kvm_vmname]};

$[/myProject/procedure_helpers/preamble]

$gt->revert();
exit($opts->{exitcode});