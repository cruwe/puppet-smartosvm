Puppet::Type.type(:smartosvm).provide(:smartosvm) do
  desc "Provider for SmartOS Virtual Machines."

  commands :vmadm => 'vmadm'
  commands :shell => 'bash'
  commands :zfs   => 'zfs'

#----------------------------------------------------------------------#
# parsers to get parameters and properties 
#----------------------------------------------------------------------#
  
  def self.instances
    $optionsstring = 'alias,uuid,state,brand,image_uuid,dns_domain,cpu_cap,cpu_shares,hostname,max_locked_memory,max_lwps,max_physical_memory,max_swap,quota,tmpfs,zfs_io_priority,zpool'

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
                                      zfs_io_priority,
                                      zpool = line.split(":")
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
            :zfs_io_priority => zfs_io_priority,
            :zpool => zpool)
    end
  end

  def self.prefetch(resources)
    vms = instances
    resources.keys.each do |aliasname|
      if provider = vms.find{ |vm| vm.aliasname == aliasname }
        resources[aliasname].provider = provider
      end
    end
  end

 def initialize(value={})
   super(value)
   @property_flush = {}
 end

#----------------------------------------------------------------------#
# query functions to determine if exists and if running
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
# setter function to collect changed values and "flush" in one single
# programm call instead of multiple
#
# primarily, such a function is used for performance reasons (one call
# is faster than n calls, but the first implementation is acutally
# necessary due to how vmadm(1M) deals with inconsistent memory
# paramters 
#----------------------------------------------------------------------#

   def flush
     vm_settings = []

     if @property_flush

       # if the flush method applies any memory changes, validate them
       if @property_flush[:max_physical_memory] or @property_flush[:max_locked_memory] or @property_flush[:max_swap]
         validate_memory 
       end

       if @property_flush[:max_physical_memory]
         new = 'max_physical_memory=' + @property_flush[:max_physical_memory]
         vm_settings << new
       end

       if @property_flush[:max_locked_memory]
         new = 'max_locked_memory=' + @property_flush[:max_locked_memory]
         vm_settings << new
       end

       if @property_flush[:max_swap]
         new = 'max_swap=' + @property_flush[:max_swap]
         vm_settings << new
       end

       unless vm_settings.empty?
         vmadm(:update, @property_hash[:uuid], vm_settings)
       end

#     @property_hash = resource.to_hash
     end
   end

#----------------------------------------------------------------------#
# helper functions to catch undesirable behaviour of vmadm(1M)
#----------------------------------------------------------------------#

   def validate_memory

     # this function is necessary because vmadm(1M) takes inconsistent
     # values and commits legally, but differently. the operator needs
     # at least to be made aware.
     
     # current values of virtual machine 
     phys = max_physical_memory
     lock = max_locked_memory
     swap = max_swap

     # are changed values available?
      if @property_flush[:max_physical_memory]
        phys = @property_flush[:max_physical_memory]
      end
      if @property_flush[:max_locked_memory]
        lock = @property_flush[:max_locked_memory]
      end
      if @property_flush[:max_swap]
        $swap = @property_flush[:max_swap]
      end

      if phys < lock or phys > swap
        warning("Your settings for the virtual machine with alias " +
                aliasname +
                " do not make sense. The settings must conform to the relation L <= P <= S. You specified L = " + lock + " <= P = " + phys + " <= S = " + swap + ", which evidently is false. vmadm(1M) will apply a legal setting, BUT THIS IS NOT THE SETTING YOU SPECIFIED.")
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


  def max_locked_memory
    @property_hash[:max_locked_memory]
  end
  def max_locked_memory=(value)
    @property_flush[:max_locked_memory] = value
  end


  def max_lwps
    @property_hash[:max_lwps]
  end
  def max_lwps=(value)
    vmadm(:update, @property_hash[:uuid], 'max_lwps=' + value.to_s)
  end


  def max_physical_memory
    @property_hash[:max_physical_memory]
  end
  def max_physical_memory=(value)
    @property_flush[:max_physical_memory] = value
  end

  def max_swap
    @property_hash[:max_swap]
  end
  def max_swap=(value)
    @property_flush[:max_swap] = value
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

  #this needs to be reimplemented so that zfs is not executed every time
  def zfs_root_compression
    zfs(:get, '-Ho', 'value', 'compression', zpool.to_s + '/' + uuid.to_s)
  end
  def zfs_root_compression=(value)
    zfs(:set, 'compression=' + value.to_s, zpool.to_s + '/' + uuid.to_s)
  end

  #this needs to be reimplemented so that zfs is not executed every time
  def zfs_root_recsize
    zfs(:get, '-Ho', 'value', 'recordsize', zpool.to_s + '/' + uuid.to_s)
  end
  def zfs_root_recsize=(value)
    zfs(:set, 'recordsize=' + value.to_s, zpool.to_s + '/' + uuid.to_s)
  end

#----------------------------------------------------------------------#
# netif related props
#----------------------------------------------------------------------#

  def ip
    @property_hash[:ip]
  end

  def netmask
    @property_hash[:netmask]
  end

  def gateway
    @property_hash[:gateway]
  end


  def resolvers
    @property_hash[:resolver]
  end


#----------------------------------------------------------------------#
# create method - very dirty and relies on constucting json as flat
# file and feeding that via /tmp to vmadm 
#----------------------------------------------------------------------#

  #TODO: find out why all calls to @resource return BUT
  #@resource[:aliasname] and why ONLY joyent is evaluated as symbol 

def create
    $zonedefjson = '{'
    $zonedefjson += '\"alias\": \"' + resource[:aliasname] + '\",'
    $zonedefjson += '\"hostname\" : \"' + resource[:aliasname] + "." + @resource[:dns_domain] +  '\",' 
     $zonedefjson += '\"brand\" : \"' + @resource[:brand].to_s + '\",'
     $zonedefjson += '\"dataset_uuid\" : \"' + @resource[:image_uuid] + '\",'
  
    # $zonedefjson += '\"max_physical_memory\" : \"' + @resource[:max_physical_memory] + '\",'
    # $zonedefjson += '\"quota\" : \"' + @resource[:quota] + '\",'
     #
     $zonedefjson += '\"nics\" : [ {'
     $zonedefjson += '\"nic_tag\" : \"admin\",'
     $zonedefjson += '\"ip\" : \"' + @resource[:ip] + '\",'
     $zonedefjson += '\"netmask\" : \"' + @resource[:netmask] + '\",'
     $zonedefjson += '\"gateway\" : \"' + @resource[:gateway] + '\"'
     $zonedefjson += ' } ],'
     $zonedefjson += '\"resolvers\" : [\"' + @resource[:resolvers] + '\"]'
    $zonedefjson += ' }'

    $zonedeffile = '/tmp/' + resource[:aliasname] + '.zonedef'

    shell('-c', 'echo ' + $zonedefjson + ' > ' + $zonedeffile)
    shell('-c', 'vmadm create -f ' + $zonedeffile)
  end



#  def destroy
#    vmadm(:destroy, @resource[:name])
#  end#

end
