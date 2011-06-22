##########################
# clone.pl
##########################
use warnings;
use strict;
use utf8;


my $opts;

$opts->{kvm_number_of_clones} = q{$[kvm_number_of_clones]};
$opts->{kvm_original_vmname} = q{$[kvm_original_vmname]};
$opts->{kvm_vmname} = q{$[kvm_vmname]};

$[/myProject/procedure_helpers/preamble]

$gt->clone();
exit($opts->{exitcode});