##########################
# create.pl
##########################
use warnings;
use strict;
use utf8;

my $opts;

$opts->{kvm_number_of_vms} = q{$[kvm_number_of_vms]};
$opts->{kvm_vmname} = q{$[kvm_vmname]};
$opts->{kvm_memory}  = q{$[kvm_memory]};
$opts->{kvm_cpu_arch} = q{$[kvm_cpu_arch]};
$opts->{kvm_num_cpus} = q{$[kvm_num_cpus]};
$opts->{kvm_storage_method} = q{$[kvm_storage_method]};
$opts->{kvm_pool_name} = q{$[kvm_pool_name]};
$opts->{kvm_device_type} = q{$[kvm_device_type]};
$opts->{kvm_disk_path} = q{$[kvm_disk_path]};
$opts->{kvm_disksize} = q{$[kvm_disksize]};
$opts->{kvm_disk_format} = q{$[kvm_disk_format]};
$opts->{kvm_guest_type} = q{$[kvm_guest_type]};
$opts->{kvm_install_method} = q{$[kvm_install_method]};
$opts->{kvm_install_source_path} = q{$[kvm_install_source_path]};
$opts->{kvm_network_type} = q{$[kvm_network_type]};
$opts->{kvm_network} = q{$[kvm_network]};
$opts->{kvm_vnclisten_ip} = q{$[kvm_vnclisten_ip]};




$[/myProject/procedure_helpers/preamble]

$gt->create();
exit($opts->{exitcode});