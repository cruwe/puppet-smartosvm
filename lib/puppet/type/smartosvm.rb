module Puppet
  newtype(:smartosvm) do

    ensurable

#----------------------------------------------------------------------#
# state property
#----------------------------------------------------------------------#

    newproperty(:state) do
      desc "This property exposes the current state of a VM."
    end

#----------------------------------------------------------------------#
# parameters - immutable
#----------------------------------------------------------------------#

    # PRIMARY KEY FOR PUPPET
    newparam(:aliasname, :namevar => true) do
      desc "An alias (originally 'alias', but reserved keyword in
            puppet/ruby, thus rename) for a VM which is for
            display/lookup purposes only. Even if not required to be
            unique on  machine, UNIQUE FOR THE PURPOSES OF THIS
            PROVIDER." 
    end

    # PRIMARY KEY FOR SMARTOS
    newparam(:uuid) do
      desc "This is the unique identifer for the VM. If one is not
           passed in with the create request, a new UUID will be
           generated. It cannot be changed after a VM is created."
      newvalues(/[[:xdigit:]]-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/)
    end

    newparam(:brand) do
      desc "This will be one of 'joyent' or 'joyent-minimal' for OS
            virtualization and 'kvm' for full hardware
            virtualization. This is a required value for VM creation." 
      newvalues("joyent", "joyent-minimal", "kvm")
    end

    newparam(:dataset_uuid) do
      desc "This should be a UUID identifying the image for the VM if
           a VM was created from an image. NOTICE: This field is named
           'dataset_uuid' on creation (vmadm create) and 'image_uuid'
           at runtime (vmadm get). DO NOT GET CONFUSED."
      newvalues(/[[:xdigit:]]-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/)
end
    
    # striclty speaking, validation is wrong as domainname parts have
    # finite lengths
    newparam(:dns_domain) do
      desc "For OS VMs this specifies the domain value for /etc/hosts
           that gets set at create time. Updating this after create
           will have no effect."
      newvalues(/[[:word:]]/)
    end
        
#----------------------------------------------------------------------#
# properties - mutable
#----------------------------------------------------------------------#

    newproperty(:cpu_cap) do
      desc "Sets a limit on the amount of CPU time that can be used by
           a VM. The unit used is the percentage of a single CPU that
           can be used by the VM. Eg. a value of 300 means up to 3
           full CPUs."
      newvalues(/[[:digit:]]+/)
    end

    newparam(:cpu_shares) do
      desc "Sets a limit on the number of fair share scheduler (FSS)
           CPU shares for a VM. This value is relative to all other
           VMs on the system, so a value only has meaning in relation
           to other VMs. If you have one VM with a value 10 and
           another with a value of 50, the VM with 50 will get 5x as
           much time from the scheduler as the one with 10 when there
           is contention."
      newvalues(/[[:digit:]]+/)
    end

    newproperty(:fs_allowed) do
      desc "This option allows you to specify filesystem types this
             zone is allowed to mount.  For example on a zone for
             building SmartOS you probably want to set this to:
             'ufs,pcfs,tmpfs'. To unset this property, set the value
             to the empty string."
      newvalues(:pcfs,:ufs,:tmpfs)
    end

    newproperty(:hostname) do
      desc "For KVM VMs, this value will be handed out via DHCP as the
            hostname for the VM. For OS VMs, this value will get set
            in several files at creation time, but CHANGING IT LATER
            WILL DO NOTHING."
      newvalues(/[[:word:]]/)
    end

    newproperty(:max_locked_memory) do
      desc "GUARANTEED PHYICAL MEM -The total amount of physical
            memory in the host than can be locked for this VM. This
            value CANNOT BE HIGHER than max_physical_memory."
      newvalues(/[[:digit:]]/)
    end

    newparam(:max_lwps) do
      desc "The maximum number of lightweight processes this VM is
            allowed to have running on the host."
      newvalues(/[[:digit:]]/)
    end

    newproperty(:max_physical_memory) do
      desc "The maximum amount of phyiscal memory on the host that the
            VM is allowed to use. For KVM VMs, this value cannot be
            lower than 'ram' and should be ram + 1024."
      newvalues(/[[:digit:]]/)
    end

    newparam(:max_swap) do
      desc "MAX VIRTUAL MEMORY - The maximum amount of virtual memory
            the VM is allowed to  use.  This cannot be lower than
            max_physical_memory." 
      newvalues(/[[:digit:]]/)
    end

    newproperty(:quota) do
      desc "This sets a quota on the zone filesystem. For OS VMs, this
            value is the space actually visible/usable in the
            guest. For KVM VMs, this value is the quota for the Zone
            containing the VM, which is not directly available to
            users. SET QUOTA TO 0 TO DISABLE (ie. for no quota)."
      newvalues(/[[:digit:]]/)
    end

    newproperty(:tmpfs) do
      desc "This property specifies how much of the VM's memory will
            be available for the /tmp filesystem. This is only
            available for OS VMs, and doesn't  make any sense for KVM
           VMs." 
      newvalues(/[[:digit:]]/)
    end

    newproperty(:zfs_io_priority) do
      desc "This sets an IO throttle priority value relative to other
           VMs. If one VM has a value X and another VM has a value 2X,
           the machine with the X value will have some of its IO
           throttled when both try to use all available IO."
      newvalue(/[[:digit:]]/)
    end

    newproperty(:zfs_root_compression) do
      desc "Specifies a compression algorithm used for this VM's root
            dataset. This option affects only the zoneroot
            dataset. Setting to 'on' is equivalent to setting to
            'lzjb'. If you want more information about the specific
            compression types, see the man page for zfs(1m). 

            WARNING: If you CHANGE this value for an EXISTING VMs,
            ONLY NEW DATA will be compressed. It will not rewrite
            existing data compress.

            ONLY FOR ZONES."
      newvalue(:on,:off,:lzjb,:gzip,/gzip-[[:digit]]/,:zle)
    end

    newproperty(:zfs_root_recsize) do
      desc "Specifies a suggested block size for files in the root
            file system. This property is designed solely for use with
            database workloads that access files in fixed-size
            records. ZFS automatically tunes block sizes according to
            internal algorithms optimized for typical access
            patterns. If you have a delegated dataset (NOT FROM PUPPET
            PROVIDER, SENSEIBLY DONE WITH ZONECFG) you should consider
            leaving this unset and setting zfs set recordsize instead.

            WARNING: Use this property only if you know exactly what
            you're doing as it is very possible to have an adverse
            effect performance when setting this incorrectly. Also,
            when doing an update, keep in mind that changing the file
            system's recordsize affects only files created after the
            setting is changed; existing files are unaffected. 

            ONLY FOR ZONES."
      newvalue(/[[:digit:]]/)

      validate do |value|
        integer = Integer(value)
        if $integer < 512
          raise ArgumentError,
          "zfs recordsize MUST be equal or greater than 512 ( recsize >= 512)"
        elsif $integer % 2 != 0
          "zfs recordsize MUST be power of two ( recsize =! x^2)"
        else
          super
        end
      end
    end

#----------------------------------------------------------------------#
# networking interfaces and properties to be properly implemented
# later
#----------------------------------------------------------------------#

    newparam(:resolvers) do
      desc ""
    end

    newparam(:ip) do # -> property
      desc ""
    end

    newparam(:netmask) do
      desc ""
    end

    newparam(:gateway) do
      desc ""
    end        

  end
end
