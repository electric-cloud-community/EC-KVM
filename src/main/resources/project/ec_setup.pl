my %Create = (
    label       => "KVM - Create",
    procedure   => "Create",
    description => "Create a Virtual Machine",
    category    => "Resource Management"
);

my %CreateResourceFromVM = (
    label       => "KVM - Create Resource From VM",
    procedure   => "CreateResourceFromVM",
    description => "Store information about a Virtual Machine and create ElectricCommander resources",
    category    => "Resource Management"
);

my %Destroy = (
    label       => "KVM - Destroy",
    procedure   => "Destroy",
    description => "Terminate the Virtual Machine",
    category    => "Resource Management"
);

my %Start = (
    label       => "KVM - Start",
    procedure   => "Start",
    description => "Start a Virtual Machine",
    category    => "Resource Management"
);

my %ShutDown = (
    label       => "KVM - ShutDown",
    procedure   => "ShutDown",
    description => "Gracefully Shut Down a Virtual Machine",
    category    => "Resource Management"
);

my %Resume = (
    label       => "KVM - Resume",
    procedure   => "Resume",
    description => "Move a Virtual Machine out of the suspended state",
    category    => "Resource Management"
);

my %Suspend = (
    label       => "KVM - Suspend",
    procedure   => "Suspend",
    description => "Suspend a running Virtual Machine",
    category    => "Resource Management"
);

my %Clone = (
    label       => "KVM - Clone",
    procedure   => "Clone",
    description => "Define a new guest with an identical virtual hardware configuration of any existing Virtual Machine",
    category    => "Resource Management"
);

my %Snapshot = (
    label       => "KVM - Snapshot",
    procedure   => "Snapshot",
    description => "Create a snapshot of a Virtual Machine",
    category    => "Resource Management"
);

my %Revert = (
    label       => "KVM - Revert",
    procedure   => "Revert",
    description => "Revert the Virtual Machine to the a snapshot specified",
    category    => "Resource Management"
);

my %CleanUp = (
    label       => "KVM - CleanUp",
    procedure   => "CleanUp",
    description => "Clean up a Virtual Machine",
    category    => "Resource Management"
);

my %List = (
    label       => "KVM - List",
    procedure   => "List",
    description => "List all existing Virtual Machines by state",
    category    => "Resource Management"
);

my %Undefine = (
    label       => "KVM - Undefine",
    procedure   => "Undefine",
    description => "Delete a Virtual Machine",
    category    => "Resource Management"
);

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Create");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Create Resource From VM");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - CreateResourceFromVM");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Destroy");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Start");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - ShutDown");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Resume");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Suspend");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Clone");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Snapshot");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Revert");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - CleanUp");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - List");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/KVM - Undefine");

@::createStepPickerSteps = (\%Create, \%CreateResourceFromVM, \%Destroy, \%Start, \%ShutDown, \%Resume, \%Suspend, \%Clone, \%Snapshot, \%Revert, \%CleanUp, \%List, \%Undefine);