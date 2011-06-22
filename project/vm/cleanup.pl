##########################
# cleanup.pl
##########################
use warnings;
use strict;
use utf8;

my $opts;

$opts->{kvm_vmname} = q{$[kvm_vmname]};
$opts->{kvm_delete_vm} = q{$[kvm_delete_vm]};
$opts->{kvm_number_of_vms} = q{$[kvm_number_of_vms]};

$[/myProject/procedure_helpers/preamble]

$gt->cleanup();
exit($opts->{exitcode});