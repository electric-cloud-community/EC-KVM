##########################
# undefine.pl
##########################
use warnings;
use strict;
use utf8;


my $opts;

$opts->{kvm_number_of_vms} = q{$[kvm_number_of_vms]};
$opts->{kvm_vmname} = q{$[kvm_vmname]};

$[/myProject/procedure_helpers/preamble]

$gt->undefine();
exit($opts->{exitcode});