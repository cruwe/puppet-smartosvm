Puppet::Type.type(:smartosvm).provide(:smartosvm) do
  desc "Provider for SmartOS Virtual Machines."

  commands :vmadm => 'vmadm'
  commands :shell => 'bash'

#----------------------------------------------------------------------#
# parsers to get parameters and properties 
#----------------------------------------------------------------------#
  
  def self.instances
    $optionsstring = 'alias,uuid,state,brand,image_uuid,dns_domain,cpu_cap,cpu_shares,hostname,max_locked_memory,max_lwps,max_physical_memory,max_swap,quota,tmpfs,zfs_io_priority'

    vms = vmadm(:list, '-Hp', '-o', $optionsstring)
    vms.split("\n").collect do |line| aliasname,
                                      uuid,
                                      state,
                                      brand,
                                      image_uuid,
                                      dns_domain,
                                      cpu_cap,
                                      cpu_shares,
                                      hostname,
                                      max_locked_memory,
                                      max_lwps,
                                      max_physical_memory,
                                      max_swap,
                                      quota,
                                      tmpfs,
                                      zfs_io_priority = line.split(":")
      new(  :aliasname => aliasname,
            :ensure => :present,
            :uuid => uuid,
            :state => state,
            :brand => brand,
            :image_uuid => image_uuid,
            :dns_domain => dns_domain,
            :cpu_cap => cpu_cap,
            :cpu_shares => cpu_shares,
            :hostname => hostname,
            :max_locked_memory => max_locked_memory,
            :max_lwps => max_lwps,
            :max_physical_memory => max_physical_memory,
            :max_swap => max_swap,
            :quota => quota,
            :tmpfs => tmpfs,
            :zfs_io_priority => zfs_io_priority)
    end
  end

  def self.prefetch(resources)
    vms = instances
    resources.keys.each do |key|
      if provider = vms.find{ |vm| vm.aliasname == key }
        resources[key].provider = provider
      end
    end
  end

#----------------------------------------------------------------------#
# self explanatory
#----------------------------------------------------------------------#

  def exists?
    @property_hash[:ensure] == :present
  end

  def state
    @property_hash[:state]
  end

  def state=(value)
    case value 
    when :running
      vmadm(:boot, uuid)
    when stopped
      vmadm(:stop, uuid)
    end
  end


#----------------------------------------------------------------------#
# parameters - immutable
#----------------------------------------------------------------------#

  def aliasname
    @property_hash[:aliasname]
  end

  def uuid
    @property_hash[:uuid]
  end

  def brand
    @property_hash[:brand]
  end

  def image_uuid
    @property_hash[:image_uuid]
  end

  def dns_domain
    @property_hash[:dns_domain]
  end

  def zpool
    @property_hash[:zpool]
  end

#-----------------------------------------------------------------------
# helper functions 
#-----------------------------------------------------------------------

  def validate_memory 
    if (@resource[:max_physical_memory] > @resource[:max_locked_memory])
      raise ArgumentError,
      "Any tupel of max_physical_memory P, max_locked_memory L
      and max_swap V MUST pass the test P <= L <= V." 
    elsif
      (@resource[:max_locked_memory] > @resource[:max_swap])
      raise ArgumentError,
      "Any tupel of max_physical_memory P, max_locked_memory L
                  and max_swap V MUST pass the test P <= L <= V." 
    else invalid = false
    end
  end
    
#----------------------------------------------------------------------#
# properties - mutable / getter and setters
#----------------------------------------------------------------------#

  def cpu_cap
    @property_hash[:cpu_cap]
  end
  def cpu_cap=(value)
   vmadm(:update, @property_hash[:uuid], 'cpucap=' + value.to_s)
  end


  def cpu_shares
    @property_hash[:cpu_shares]
  end
  def cpu_shares=(value)
   vmadm(:update, @property_hash[:uuid], 'cpu_shares=' + value.to_s)
  end


  def hostname
    @property_hash[:hostname]
  end
  # this needs case distinction between zones and kvm vms as vmadm is
  # only useful for kvm vms and for zones this has to be done
  # internally 
  # def hostname=(value)
  # end


  # TODO - proper validation
  def max_locked_memory
    @property_hash[:max_locked_memory]
  end
  def max_locked_memory=(value)
    validate_memory
    vmadm(:update, @property_hash[:uuid], 'max_locked_memory=' + value.to_s)
  end


  def max_lwps
    @property_hash[:max_lwps]
  end
  def max_lwps=(value)
    vmadm(:update, @property_hash[:uuid], 'max_lwps=' + value.to_s)
  end


  # TODO - proper validation
  def max_physical_memory
    @property_hash[:max_physical_memory]
  end
  def max_physical_memory=(value)
    validate_memory
    vmadm(:update, @property_hash[:uuid], 'max_physical_memory=' + value)
  end


  # TODO - proper validation
  def max_swap
    @property_hash[:max_swap]
  end
  def max_swap=(value)
    validate_memory
   vmadm(:update, @property_hash[:uuid], 'max_swap=' + value.to_s)
  end


  def quota
    @property_hash[:quota]
  end
  def quota=(value)
   vmadm(:update, @property_hash[:uuid], 'quota=' + value.to_s)
  end


  def tmpfs
    @property_hash[:tmpfs]
  end
  def tmpfs=(value)
    vmadm(:update, @property_hash[:uuid], 'tmpfs=' + value.to_s)
  end


  def zfs_io_priority
    @property_hash[:zfs_io_priority]
  end
  def zfs_io_priority=(value)
    vmadm(:update, @property_hash[:uuid], 'zfs_io_priority=' + value.to_s)
  end

  # this needs to be implemented using zfs
  # def zfs_root_compression
  # end
  # def zfs_root_compression=(value)
  # end

  # this needs to be implemented using zfs
  # def zfs_root_recsize
  # end
  # def zfs_root_recsize=(value)
  # end


#----------------------------------------------------------------------#
# create method - very dirty and relies on constucting json as flat
# file and feeding that via /tmp to vmadm 
#----------------------------------------------------------------------#

  def create
    $zonedefjson = '{'
    $zonedefjson += '\"alias\": \"' + @resource[:aliasname] + '\",'
    $zonedefjson += '\"hostname\" : \"' + @resource[:aliasname] + "." + @resource[:dns_domain] +  '\",' 
    $zonedefjson += '\"brand\" : \"' + @resource[:brand] + '\",'
    $zonedefjson += '\"dataset_uuid\" : \"' + @resource[:image_uuid] + '\",'
    #
    $zonedefjson += '\"max_physical_memory\" : \"' + @resource[:max_physical_memory] + '\",'
    $zonedefjson += '\"quota\" : \"' + @resource[:quota] + '\",'
    #
    $zonedefjson += '\"nics\" : [ {'
    $zonedefjson += '\"nic_tag\" : \"admin\",'
    $zonedefjson += '\"ip\" : \"' + @resource[:ip] + '\",'
    $zonedefjson += '\"netmask\" : \"' + @resource[:netmask] + '\",'
    $zonedefjson += '\"gateway\" : \"' + @resource[:gateway] + '\"'
    $zonedefjson += ' } ],'
    $zonedefjson += '\"resolvers\" : [\"' + @resource[:resolvers] + '\"]'
    $zonedefjson += ' }'

    $zonedeffile = '/tmp/' + @resource[:aliasname] + '.zonedef'

    shell('-c', 'echo ' + $zonedefjson + ' > ' + $zonedeffile)
    shell('-c', 'vmadm create -f ' + $zonedeffile)
  end

#  def destroy
#    vmadm(:destroy, @resource[:name])
#  end#

end
