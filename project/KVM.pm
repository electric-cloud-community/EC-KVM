# -------------------------------------------------------------------------
# Package
#    KVM.pm
#
# Dependencies
#    ElectricCommander.pm
#
# Purpose
#     A perl library that encapsulates the logic to manipulate virtual machines on KVM using libvirt API
#
# Plug-in Version
#    1.0
#
# Date
#    06/10/2011
#
# Engineer
#    Andres Arias
#
# Copyright (c) 2011 Electric Cloud, Inc.
# All rights reserved
# -------------------------------------------------------------------------

package KVM;

# -------------------------------------------------------------------------
# Includes
# -------------------------------------------------------------------------
use warnings;
use strict;
use ElectricCommander;
use ElectricCommander::PropDB;
use Fcntl;

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------
use constant {
    SUCCESS => 0,
    ERROR   => 1,
    
    TRUE  => 1,
    FALSE => 0,
    
    ALIVE => 1,
    NOT_ALIVE => 0,
    
    DEFAULT_DEBUG        => 1,
    DEFAULT_PING_TIMEOUT => 300,
    DEFAULT_PROPERTIES_LOCATION => '/myJob/KVM/vms',
    DEFAULT_NUMBER_OF_VMS => 1,
    DEFAULT_DISKSIZE      => 4,
    DEFAULT_MEMORY        => 512,
    DEFAULT_NUM_CPUS      => 1,
    DEFAULT_ARCH => 'i386',
    DEFAULT_POOLDEVICETYPE => "disk",
    
    WAIT_SLEEP_TIME => 15,

    TASK_SUCCESS => 1,
    TASK_ERROR   => 2,
    
};

################################
# new - Object constructor for KVM
#
# Arguments:
#   opts hash
#
# Returns:
#   none
#
################################
sub new {
    my ( $class, $cmdr, $opts ) = @_;
    my $self = { 
        _cmdr => $cmdr,
        _opts => $opts, 
    };
    bless $self, $class;
}

###############################
# myCmdr - Get ElectricCommander instance
#
# Arguments:
#   none
#
# Returns:
#   ElectricCommander instance
#
################################
sub myCmdr {
    my ($self) = @_;
    return $self->{_cmdr};
}

###############################
# myProp - Get PropDB
#
# Arguments:
#   none
#
# Returns:
#   PropDB
#
################################
sub myProp {
    my ($self) = @_;
    return $self->{_props};
}

###############################
# setProp - Use stored property prefix and PropDB to set a property
#
# Arguments:
#   location - relative location to set the property
#   value    - value of the property
#
# Returns:
#   setResult - result returned by PropDB->setProp
#
################################
sub setProp {
    my ($self, $location, $value) = @_;
    my $setResult = $self->myProp->setProp($self->opts->{kvm_properties} . $location, $value);
    return $setResult;
}

################################
# opts - Get opts hash
#
# Arguments:
#   none
#
# Returns:
#   opts hash
#
################################
sub opts {
    my ($self) = @_;
    return $self->{_opts};
}

################################
# ecode - Get exit code
#
# Arguments:
#   none
#
# Returns:
#   exit code number
#
################################
sub ecode {
    my ($self) = @_;
    return $self->opts()->{exitcode};
}

################################
# initialize - Set initial values
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub initialize {
    my ($self) = @_;
    
    # Set defaults 
    $self->opts->{Debug} = DEFAULT_DEBUG;
    $self->opts->{exitcode} = SUCCESS;
    $self->opts->{kvm_properties} = DEFAULT_PROPERTIES_LOCATION;
    
    if(defined($self->opts->{kvm_number_of_vms}) && ($self->opts->{kvm_number_of_vms} eq "" or $self->opts->{kvm_number_of_vms} <= 0)) {
        $self->opts->{kvm_number_of_vms} = DEFAULT_NUMBER_OF_VMS;
    }

    if(defined($self->opts->{kvm_disksize}) && $self->opts->{kvm_disksize} eq "") {
        $self->opts->{kvm_disksize} = DEFAULT_DISKSIZE;
    }
    if(defined($self->opts->{kvm_memory}) && $self->opts->{kvm_memory} eq "") {
        $self->opts->{kvm_memory} = DEFAULT_MEMORY;
    }
    if(defined($self->opts->{kvm_num_cpus}) && $self->opts->{kvm_num_cpus} eq "") {
        $self->opts->{kvm_num_cpus} = DEFAULT_NUM_CPUS;
    }   
    if(defined($self->opts->{kvm_cpu_arch}) && $self->opts->{kvm_cpu_arch} eq "") {
        $self->opts->{kvm_cpu_arch} = DEFAULT_ARCH;
    }
    
    if(defined($self->opts->{kvm_device_type}) && $self->opts->{kvm_device_type} eq "") {
        $self->opts->{kvm_device_type} = DEFAULT_POOLDEVICETYPE;
    }
    
    
}

###############################
# checkOption - Check option depending on flags
#
# Arguments:
#   option - name of the option
#   flags - requirements to check
#
# Returns:
#   0 - Success
#   1 - Error
#
###############################
sub checkOption {
    my ($self, $option, $flags) = @_;

    if (defined($self->opts->{$option}) ) {
        if ($flags =~ /noblank/ && $self->opts->{$option} eq "") {
            $self->debugMsg(0,"required option $option is blank");
            return ERROR;
        } elsif ($self->opts->{$option} eq "") {
            $self->opts->{$option} = "";
        }
    } else {
        if ($flags =~ /required/) {
            $self->debugMsg(0,"required option $option not found");
            return ERROR;
        }
    }
    return SUCCESS;
}

################################
# create - Call create_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub create {
    my ($self) = @_;            
       
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->create_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->create_vm();
        }
    }
 }

################################
# create_vm - Call virt-image to create a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################    
sub create_vm {    
    my ($self) = @_;
    
    my $storage_command = '';
    my $install_command = '';
    my $network_command = '';
    #Check for required parameters
    if($self->opts->{kvm_storage_method} == 0) { 
        if ($self->checkOption("kvm_pool_name","required noblank") || $self->checkOption("kvm_device_type", "required noblank")) {
        $self->opts->{exitcode} = ERROR;
        return;
        }
        else{
            $storage_command = 'pool='.$self->opts->{kvm_pool_name}.',device='.$self->opts->{kvm_device_type};
        }
    }
    else { 
        if ($self->checkOption("kvm_disk_path","required noblank")) { 
        $self->opts->{exitcode} = ERROR;
        return; 
        }
        else{
            $storage_command = 'path='.$self->opts->{kvm_disk_path};
        }
    }
     if ($self->checkOption("kvm_install_source_path","required noblank") || $self->checkOption("kvm_network", "required noblank")) {
        $self->opts->{exitcode} = ERROR;
        return;
     }
     
     if($self->opts->{kvm_install_method} == 0) {
        $install_command = '--cdrom '. $self->opts->{kvm_install_source_path};     
     }
     else {
        $install_command = '--location '. $self->opts->{kvm_install_source_path}; 
     }
     if($self->opts->{kvm_network_type} == 0) {
        $network_command = 'bridge:'.$self->opts->{kvm_network};     
     }
     else {
        $network_command = 'network:'.$self->opts->{kvm_network}; 
     }
     if(defined($self->opts->{kvm_vnclisten_ip}) && $self->opts->{kvm_vnclisten_ip} eq '') {
        #Get host IP
        my $ip_addr_cdm = "hostname -i";
        my $ip_addr = `hostname -i`;
        $ip_addr =~ s/\n//g;
        
        $self->opts->{kvm_vnclisten_ip} = $ip_addr;
    }

    # Create command
    my $command = 'virt-install -d --connect qemu:///system --name '.$self->opts->{kvm_vmname}.' --ram '.$self->opts->{kvm_memory}.' --hvm --arch '.$self->opts->{kvm_cpu_arch}.' --vcpus '.$self->opts->{kvm_num_cpus}.'  --disk '.$storage_command.',size='.$self->opts->{kvm_disksize}.',format='.$self->opts->{kvm_disk_format}.' '.$install_command.' --os-type '.$self->opts->{kvm_guest_type}.' --graphics vnc,listen='.$self->opts->{kvm_vnclisten_ip}.',keymap=no --network '.$network_command.' --noautoconsole';
    
    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "Creating virtual machine '".$self->opts->{kvm_vmname}."'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully created.";
        return $out;
    } 
     
    # Execute command
    $self->debugMsg(1, 'Creating virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { 
        $result = system($command); 
    };
   
    #If an error occured
    if ($result) {    
        print  "Error trying to create virtual machine \'".$self->opts->{kvm_vmname}."\'\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result; 
        return;
     }
    my  $command_listen = 'virsh vncdisplay '.$self->opts->{kvm_vmname};
    print "VNC listen:";
    system($command_listen);
    $self->debugMsg(1, 'Virtual machine \''.$self->opts->{kvm_vmname}.'\' successfully created.');   
}

################################
# start - Call start_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub start {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->start_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->start_vm();
        }
    }
 }

################################
# start_vm - Call virsh to start a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub start_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system start '. $self->opts->{kvm_vmname};
    
    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "Starting virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully started.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Starting virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # If an error occured
    if ($result) {
        print  "Error trying to start virtual machine \'".$self->opts->{kvm_vmname}."\'\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully started.");
}

################################
# shutdown - Call shutdown_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub shutdown {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->shutdown_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->shutdown_vm();
        }
    }
 }

################################
# shutdown_vm - Call virsh to shutdown a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub shutdown_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system shutdown '. $self->opts->{kvm_vmname};

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Shutting Down virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' shutdown successfully.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Shutting Down virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); 
    $self->checkStatus('shut off');
    };
    
    # If an error occured
    if ($result || $self->opts->{exitcode}) {
        print  "Error trying to shutdown virtual machine \'".$self->opts->{kvm_vmname}."\'\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    
    
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' shutdown successfully.");
}

################################
# suspend - Call suspend_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub suspend {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->suspend_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->suspend_vm();
        }
    }
 }

################################
# suspend - Call virsh to suspend a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub suspend_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system suspend '. $self->opts->{kvm_vmname};

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Suspending virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully suspended.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Suspending virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # If an error occured
    if ($result) {
        print  "Error trying to suspend virtual machine \'".$self->opts->{kvm_vmname}."\'\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully suspended.");
}

################################
# resume - Call resume_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub resume {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->resume_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->resume_vm();
        }
    }
 }

################################
# resume - Call virsh to resume a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub resume_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system resume '. $self->opts->{kvm_vmname};

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Resuming virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully resumed.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Resuming virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # If an error occured
    if ($result) {
        print  "Error trying to resume virtual machine \'".$self->opts->{kvm_vmname}."\'";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully resumed.");
}

################################
# destroy - Call destroy_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub destroy {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->destroy_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->destroy_vm();
        }
    }
 }

################################
# destroy - Call virsh to destroy a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub destroy_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system destroy '. $self->opts->{kvm_vmname};

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Destroying virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully destroyed.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Destroying virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # If an error occured
    if ($result) {
        print  "Error trying to destroy virtual machine \'".$self->opts->{kvm_vmname}."\'";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully destroyed.");
}

################################
# reboot - Call reboot_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub reboot {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->reboot_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->reboot_vm();
        }
    }
 }

################################
# reboot - Call virsh to reboot a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub reboot_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system reboot '. $self->opts->{kvm_vmname};

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Rebooting virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully rebooted.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Rebooting virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # If an error occured
    if ($result) {
        print  "Error trying to reboot virtual machine \'".$self->opts->{kvm_vmname}."\'";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully rebooted.");
}

################################
# clone - Call clone_vm the number of times specified  by 'kvm_number_of_clones'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub clone {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_clones} == DEFAULT_NUMBER_OF_VMS) {
        $self->clone_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_clones} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->clone_vm();
        }
    }
 }

################################
# clone_vm - Call virt-clone to clone a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub clone_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virt-clone -d --connect qemu:///system --original '. $self->opts->{kvm_original_vmname}.' --name '. $self->opts->{kvm_vmname}.' --auto-clone';

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Cloning virtual machine \'".$self->opts->{kvm_original_vmname}."\' to \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully cloned.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Cloning virtual machine \''.$self->opts->{kvm_original_vmname}.'\' to \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # If an error occured
    if ($result) {
        print  "Error trying to clone virtual machine \'".$self->opts->{kvm_original_vmname}."\' to \'".$self->opts->{kvm_vmname}."\'";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully cloned.");
}

################################
# snapshot - Call virsh to create a snapshot of a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub snapshot {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    # Create snapshotxml file
    my $snapshotxml =     
"<domainsnapshot>
         <name>".$self->opts->{kvm_snapshot_name}."</name>
         <description>".$self->opts->{kvm_snapshot_desc}."</description> 
</domainsnapshot>";
    
    open(XML,">".$self->opts->{kvm_snapshot_name}.".xml");
    printf XML $snapshotxml;
    close (XML);
    
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system snapshot-create  '. $self->opts->{kvm_vmname}.' '. $self->opts->{kvm_snapshot_name}.'.xml';  
    
    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Creating snapshot \'".$self->opts->{kvm_snapshot_name}."\' for virtual machine  \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Snapshot \'".$self->opts->{kvm_snapshot_name}."\' on \'".$self->opts->{kvm_vmname}."\' successfully created.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Creating snapshot \''.$self->opts->{kvm_snapshot_name}.'\' for virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # Delete snapshotxml file
    unlink($self->opts->{kvm_snapshot_name}.".xml");
    
    # If an error occured
    if ($result) {
        print  "Error trying to create snapshot \'".$self->opts->{kvm_snapshot_name}."\' for virtual machine \'".$self->opts->{kvm_vmname}."\'";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Snapshot \'".$self->opts->{kvm_snapshot_name}."\' on \'".$self->opts->{kvm_vmname}."\' successfully created.");    
}

################################
# revert - Call virsh to revert a virtual machine to a snapshot
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub revert {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system snapshot-revert '. $self->opts->{kvm_vmname}.' '. $self->opts->{kvm_snapshot_name};  

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "'Reverting virtual machine \'".$self->opts->{kvm_vmname}."\' to snapshot \'".$self->opts->{kvm_snapshot_name}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully reverted to snapshot \'".$self->opts->{kvm_snapshot_name}."\'.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Reverting virtual machine \''.$self->opts->{kvm_vmname}.'\' to snapshot \''.$self->opts->{kvm_snapshot_name}.'\'...');
    my $result = system($command);
    
    # If an error occured
    if ($result) {
        print  "Error trying to revert virtual machine \'".$self->opts->{kvm_vmname}."\' to snapshot \'".$self->opts->{kvm_snapshot_name}."\'";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, 'Virtual machine \''.$self->opts->{kvm_vmname}.'\' successfully reverted to snapshot \''.$self->opts->{kvm_snapshot_name}.'\'.');
}

################################
# undefine - Call undefine_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub undefine {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->undefine_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->undefine_vm();
        }
    }
 }

################################
# undefine_vm - Call virsh to delete a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub undefine_vm {
    my ($self) = @_;
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system undefine '. $self->opts->{kvm_vmname};

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "Deleting virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully deleted.";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Deleting virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
    my $result;
    eval { $result = system($command); };
    
    # If an error occured
    if ($result) {
        print  "Error trying to delete virtual machine \'".$self->opts->{kvm_vmname}."\'\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    $self->debugMsg(1, "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully deleted.");
}

################################
# list - Call virsh to show existing virtual machines
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub list {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();
    
    # Create command
    my $command = 'virsh -d 5 --connect qemu:///system list '. $self->opts->{kvm_state_list};

    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= $command;
        $out .= "\n";
        $out .= "Listing virtual machines...";
        return $out;
    }
    
    # Execute command
    $self->debugMsg(1, 'Listing virtual machines...');
    my $result;
    eval { $result = system($command);};
    
    # If an error occured
    if ($result) {
        print  "Error trying to list virtual machines\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result;
        return;
    }
    
}

###############################
# createResourcesFromVM - Initialize and call createResources
#
# Arguments:
#   cgfId - configuration ID
#   cfgName - configuration name
#
# Returns:
#   none
#
###############################
sub createResourcesFromVM {
    my($self) = @_;

    # Initialize 
    $self->initialize();
        
    # Call procedure to deploy the configuration
    $self->createResource();
    if ($self->opts->{exitcode}) { return; }
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->createResource();
    }
    
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->createResource();
        }
    }
    
}

###############################
# createResource - Create Commander resource and save information in properties 
#
# Arguments:
#   cgfId - configuration ID
#   cfgName - configuration name
#
# Returns:
#   none
#
###############################  
sub createResource {
    my ($self) = @_;
    
    # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= "Getting information of virtual machine \'". $self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Storing properties...";
        $out .= "\n";
        $out .= "IP address: 192.168.2.25";
        $out .= "\n";
        $out .= "Hostname: debug2";
        $out .= "\n";
        $out .= "Creating resource for virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Resource created";
        $out .= "\n";
        $out .= "Waiting for ping response #(". DEFAULT_PING_TIMEOUT . ") of resource ". $self->opts->{kvm_vmname};
        $out .= "\n";
        $out .= "Ping response succesfully received";
        return $out;
    }  
    
    $self->debugMsg (1, 'Getting information of virtual machine \'' . $self->opts->{kvm_vmname} . '\'...');    
    # Create command(get mac address)
    my $result_mac = '';
    my $mac = '';
    my $result_ip = '';
    my $result_hostname = '';
    my $vname = $self->opts->{kvm_vmname};
    eval { 
    # Execute command
    #$result_mac = system($command_mac);
    $result_mac = `virsh dumpxml $vname | grep "mac address"`;
    $result_mac =~ s/.*'(.*)'.*//g;
    $mac = $1;
    # Get ip address
    #my $command_ip = 'grep $result_mac /var/log/messages | tail -n 1 | awk "{print $7}"';  
    #$result_ip = system($command_ip);
    $result_ip = `grep $mac /var/log/messages | tail -n 1 | awk '{print \$7}'`;
    $result_ip =~ s/\n//;
    #my $command_hostname = 'grep $result_mac /var/log/messages | tail -n 1 | awk "{print $9}"';  
    #$result_hostname = system($command_hostname);
    $result_hostname = `grep $mac /var/log/messages | tail -n 1 | awk '{print \$9}'`;
    $result_hostname =~ s/\n//;
    };
    
    # If an error occured
    if (!$result_ip) {
        print  "Error trying to get virtual machine ip address\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = $result_ip;
        return;
    }
    
    my $ip_address = $result_ip;
    my $hostname = $result_hostname;
    
    # Store vm info in properties
    $self->debugMsg(1, 'Storing properties...');
    $self->debugMsg(1, 'IP address: ' . $ip_address);
    $self->debugMsg(1, 'Hostname: ' . $hostname);
    
    # Create ElectricCommander PropDB and store properties
    $self->{_props} = new ElectricCommander::PropDB($self->myCmdr(),"");
    $self->setProp( '/'.$self->opts->{kvm_vmname}.'/ipAddress', $ip_address);
    $self->setProp( '/'.$self->opts->{kvm_vmname}.'/hostName', $hostname);

    # Create resource
        $self->debugMsg(1, 'Creating resource for virtual machine \''.$self->opts->{kvm_vmname}.'\'...');
        my $cmdrresult = $self->myCmdr()->createResource(
               $self->opts->{kvm_vmname},
            {description => "KVM created resource",
             hostName => $ip_address,
             pools => $self->opts->{esx_pools} } );

        # Check for error return
        my $errMsg = $self->myCmdr()->checkAllErrors($cmdrresult);
        if ($errMsg ne "") {
            $self->debugMsg(1, "Error: $errMsg");
            $self->opts->{exitcode} =  ERROR;
            return;
        }
        
        $self->debugMsg(1, 'Resource created');
        
        # Test connection to vm
        my $resStarted = 0;
        my $try  = DEFAULT_PING_TIMEOUT;
        while ($try > 0) {
            $self->debugMsg(1, "Waiting for ping response #(" . $try . ") of resource " . $self->opts->{kvm_vmname});
            my $pingresult = $self->pingResource($self->opts->{kvm_vmname});
            if ($pingresult == 1) {
                $resStarted = 1;
                last;
            }
            sleep(1);
            $try -= 1;
        }
        if ($resStarted == 0) {
            $self->debugMsg(1, 'Unable to ping virtual machine');
            $self->opts->{exitcode} =  ERROR;
        } else {
            $self->debugMsg(1, 'Ping response succesfully received');
        }
    
}

################################
# cleanup - call cleanup_vm the number of times specified  by 'kvm_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub cleanup {
    my ($self) = @_;
    
    # Initialize 
    $self->initialize();    
    
    if ($self->opts->{kvm_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->cleanup_vm();
    }
    else {
        my $vm_prefix = $self->opts->{kvm_vmname};
        my $vm_number;
        for ( my $i = 0 ; $i < $self->opts->{kvm_number_of_vms} ; $i++ ) {
            $vm_number = $i + 1;
            $self->opts->{kvm_vmname} = $vm_prefix . "_$vm_number";
            $self->cleanup_vm();
        }
    }
}

################################
# cleanup_vm - Cleanup the specified virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub cleanup_vm {
    my ($self) = @_;
    my $vm_name = $self->opts->{kvm_vmname};

        # Test mode
    if ($::gRunTest) {
        # Create and return fake output
        my $out = "";
        $out .= "Deleting resource \'". $vm_name ."\'...";
        $out .= "\n";
        $out .= "Resource deleted'";
        $out .= "\n";
        $out .= "virsh -d 5 --connect qemu:///system destroy ". $self->opts->{kvm_vmname};
        $out .= "\n";
        $out .= "'Destroying virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully destroyed.";
        $out .= "\n";        
        $out .= "virsh -d 5 --connect qemu:///system undefine ". $self->opts->{kvm_vmname};
        $out .= "\n";
        $out .= "Deleting virtual machine \'".$self->opts->{kvm_vmname}."\'...";
        $out .= "\n";
        $out .= "Virtual machine \'".$self->opts->{kvm_vmname}."\' successfully deleted.";
        return $out;
    }
    
    # Remove resource
    $self->debugMsg(1, 'Deleting resource \'' . $vm_name .'\'...');
    my $cmdrresult = $self->myCmdr()->deleteResource($vm_name);
   
    # Check for error return
    my $errMsg = $self->myCmdr()->checkAllErrors($cmdrresult);
    if ($errMsg ne "") {
        $self->debugMsg(1, "Error: $errMsg");
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $self->debugMsg(1, 'Resource deleted');

    if (defined($self->opts->{kvm_delete_vm}) && $self->opts->{kvm_delete_vm}) {

        # VM must be inactive to be undefined. If an error occurs in power_off, it can be ignored because then Cleanup is going to show the error
        my $exitcode_temp = $self->opts->{exitcode};
        $self->destroy_vm();
        $self->opts->{exitcode} = $exitcode_temp;
 
        eval {
            # Undefine the vm
            $self->undefine_vm();
        };
        if ($@) {
            $self->debugMsg(0, 'Fault' . $@);
            $self->opts->{exitcode} = ERROR;
               return;
        }
    }
}

###############################
# trim - deletes blank spaces before and after the entered value in 
# the argument
#
# Arguments:
#   untrimmedString: string that will be trimmed
#
# Returns:
#   trimmed string
#
###############################
sub trim($) {
    my ($self, $untrimmedString) = @_;
    my $string = $untrimmedString;
    $string =~ s/^\s+//;  
    $string =~ s/\s+$//; 
    return $string;
}

###############################
# pingResource - Use commander to ping a resource
#
# Arguments:
#   resource - string
#
# Returns:
#   1 if alive, 0 otherwise
#
###############################
sub pingResource {
    my ($self,$resource) = @_;

    my $alive = "0";
    my $result = $self->myCmdr()->pingResource($resource);
    if (!$result) { return NOT_ALIVE; }
    $alive = $result->findvalue('//alive');
    if ($alive eq ALIVE) { return ALIVE;}
    return NOT_ALIVE;
}

###############################
# debugMsg - Print a debug message
#
# Arguments:
#   errorlevel - number compared to $self->opts->{Debug}
#   msg        - string message
#
# Returns:
#   none
#
################################
sub debugMsg {
    my ( $self, $errlev, $msg ) = @_;
    if ( $self->opts->{Debug} >= $errlev ) { print "$msg\n"; }
}

###############################
# trim - deletes blank spaces before and after the entered value in 
# the argument
#
# Arguments:
#   untrimmedString: string that will be trimmed
#
# Returns:
#   trimmed string
#
###############################
sub checkStatus{
    my ($self, $expectedState) = @_;
    # Create command
    
    my $command = 'virsh --connect qemu:///system domstate '. $self->opts->{kvm_vmname};
    
    # Execute command
    $self->debugMsg(1, 'Waiting for \''.$self->opts->{kvm_vmname}.'\' to '.$expectedState.'...');
    my $result;
    my $retry = 0;
    while (1) {
    
    
    
        eval { $result = `$command`; };

        # If an error occured
        if ($@) {
        print  "Error trying to get virtual machine \'".$self->opts->{kvm_vmname}."\' status\n";
        $self->myCmdr->setProperty("outcome", "error" );
        $self->opts->{exitcode} = ERROR;
        return;
        }     
        $result =~ s/\n//g;
        if ( $result eq $expectedState ) {
            return TASK_SUCCESS;
        }
        elsif ( $retry gt 10 ) {
            return TASK_ERROR;
}

        #-----------------------------
        # Still running
        #-----------------------------
        sleep(WAIT_SLEEP_TIME);
    }
    
}