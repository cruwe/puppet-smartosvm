# Copyright 2013, Christopher J. Ruwe <cjr@cruwe.de>
#
# This program is free software. It may be redistributed under the
# 2-clause BSD license.

Puppet::Type.type(:smartosvm).provide(:smartosvm) do
  desc "Provider for SmartOS Virtual Machines."

  commands :vmadm => 'vmadm'
  commands :shell => 'bash'
  commands :zfs   => 'zfs'

#----------------------------------------------------------------------#
# parsers to get parameters and properties 
#----------------------------------------------------------------------#
  
  def self.instances
    $optionsstring = 'alias,uuid,state,brand,image_uuid,dns_domain,cpu_cap,cpu_shares,hostname,max_locked_memory,max_lwps,max_physical_memory,max_swap,quota,tmpfs,zfs_io_priority,zpool,nics.0.nic_tag,nics.0.mac,nics.0.ip,nics.0.netmask,nics.0.gateway,nics.0.dhcp_server,nics.1.nic_tag,nics.1.mac,nics.1.ip,nics.1.netmask,nics.1.gateway,nics.1.dhcp_server'

    vms = vmadm(:list, '-H', '-o', $optionsstring)
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
                                      zpool,
                                      nics_0_nic_tag,
                                      nics_0_mac,
                                      nics_0_ip,
                                      nics_0_netmask,
                                      nics_0_gateway,
                                      nics_0_dhcp_server,
                                      nics_1_nic_tag,
                                      nics_1_mac,
                                      nics_1_ip,
                                      nics_1_netmask,
                                      nics_1_gateway,
                                      nics_1_dhcp_server = line.split("\s")

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
            :zpool => zpool,
            :nics_0_nics_tag => nics_0_nic_tag,
            :nics_0_mac => nics_0_mac,
            :nics_0_ip => nics_0_ip,
            :nics_0_netmask => nics_0_netmask,
            :nics_0_gateway => nics_0_gateway,
            :nics_0_dhcp_server => nics_0_dhcp_server,
            :nics_1_nics_tag => nics_1_nic_tag,
            :nics_1_mac => nics_1_mac,
            :nics_1_ip => nics_1_ip,
            :nics_1_netmask => nics_1_netmask,
            :nics_1_gateway => nics_1_gateway,
            :nics_1_dhcp_server => nics_1_dhcp_server  )
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

     # anything to do?
     if @property_flush

       # if the flush method applies any memory changes, validate them
       if @property_flush[:max_physical_memory] or @property_flush[:max_locked_memory] or @property_flush[:max_swap]
         validate_memory 
       end

       #collect flushable vm_settings
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


       #commit everything with vmadm
       unless vm_settings.empty?
         vmadm(:update, @property_hash[:uuid], vm_settings)
       end

       #---------------------------------------------------------------#
       # NIC code
       #
       # json ops make things difficult - first on 0, then 1
       # 1) up or create? primary key if up, mac, if create, IF
       # 2) walk the flush and add to json
       # 3) commit the json
       #---------------------------------------------------------------#

       nic_0_json = ""
       nic_0_json_file = '/tmp/' + uuid + '.net0.def' 
       nic_0_touched = false

       nic_1_json = ""
       nic_1_json_file = '/tmp/' + uuid + '.net1.def' 
       nic_1_touched = false

       #updating or creating?
       if nics_0_mac != '-'
         nic_0_json += '{ \"update_nics\": [ {'
         nic_0_json += '\"mac\": \"' + nics_0_mac + '\"'
       else
         nic_0_json += '{ \"add_nics\": [ {'
         nic_0_json += '\"interface\": \"net0\"'
       end

       if @property_flush[:nics_0_nic_tag]
         new = ', \"nic_tag\": \"' + @property_flush[:nics_0_nic_tag] + '\"'
         nic_0_json += new
         nic_0_touched = true
       end


       if @property_flush[:nics_0_ip]
         new = ', \"ip\": \"' + @property_flush[:nics_0_ip] + '\"'
         nic_0_json += new
         nic_0_touched = true
       end


       if @property_flush[:nics_0_netmask]
         new = ', \"netmask\": \"' + @property_flush[:nics_0_netmask] + '\"'
         nic_0_json += new
         nic_0_touched = true
       end


       if @property_flush[:nics_0_gateway]
         new = ', \"gateway\": \"' + @property_flush[:nics_0_gateway] + '\"'
         nic_0_json += new
         nic_0_touched = true
       end


       if @property_flush[:nics_0_dhcp_server]
         new = ', \"dhcp_server\": \"' + @property_flush[:nics_0_dhcp_server] + '\"'
         nic_0_json += new
         nic_0_touched = true
       end

        
       # if the nic has been touched, commit
       if nic_0_touched == true
         nic_0_json += '} ] }'
         shell('-c', 'echo ' + nic_0_json + ' > ' + nic_0_json_file)
         shell('-c', 'vmadm update ' + uuid + ' -f ' + nic_0_json_file)
       end


       if nics_1_mac != '-'
         nic_1_json += '{ \"update_nics\": [ {'
         nic_1_json += '\"mac\": \"' + nics_1_mac + '\"'
       else
         nic_1_json += '{ \"add_nics\": [ {'
         nic_1_json += '\"interface\": \"net1\"'
       end

       if @property_flush[:nics_1_nic_tag]
         new = ', \"nic_tag\": \"' + @property_flush[:nics_1_nic_tag] + '\"'
         nic_1_json += new
         nic_1_touched = true
       end


       if @property_flush[:nics_1_ip]
         new = ', \"ip\": \"' + @property_flush[:nics_1_ip] + '\"'
         nic_1_json += new
         nic_1_touched = true
       end


       if @property_flush[:nics_1_netmask]
         new = ', \"netmask\": \"' + @property_flush[:nics_1_netmask] + '\"'
         nic_1_json += new
         nic_1_touched = true
       end


       if @property_flush[:nics_1_gateway]
         new = ', \"gateway\": \"' + @property_flush[:nics_1_gateway] + '\"'
         nic_1_json += new
         nic_1_touched = true
       end


       if @property_flush[:nics_1_dhcp_server]
         new = ', \"dhcp_server\": \"' + @property_flush[:nics_1_dhcp_server] + '\"'
         nic_1_json += new
         nic_1_touched = true
       end
       
        
       # if the nic has been touched, commit
       if nic_1_touched == true
         nic_1_json += '} ] }'
         shell('-c', 'echo ' + nic_1_json + ' > ' + nic_1_json_file)
         shell('-c', 'vmadm update ' + uuid + ' -f ' + nic_1_json_file)
       end

     end
     #if nothing to do, do nothing
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


  def nics_0_nic_tag
    @property_hash[:nics_0_nic_tag]
  end
  def nics_0_nic_tag=(value)
    @property_flush[:nics_0_tag] = value
  end


  def nics_0_mac
    @property_hash[:nics_0_mac]
  end


  def nics_0_ip
    @property_hash[:nics_0_ip]
  end
  def nics_0_ip=(value)
    @property_flush[:nics_0_ip] = value
  end


  def nics_0_netmask
    @property_hash[:nics_0_netmask]
  end
  def nics_0_netmask=(value)
    @property_flush[:nics_0_netmask] = value
  end


  def nics_0_gateway
    @property_hash[:nics_0_gateway]
  end
  def nics_0_gateway=(value)
    @property_flush[:nics_0_gateway] = value
  end


  def nics_0_dhcp_server
    @property_hash[:nics_0_dhcp_server]
  end
  def nics_0_dhcp_server=(value)
    @property_flush[:nics_0_dhcp_server] = value
  end

    #.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

  def nics_1_nic_tag
    @property_hash[:nics_1_nic_tag]
  end
  def nics_1_nic_tag=(value)
    @property_flush[:nics_1_tag] = value
  end


  def nics_1_mac
    @property_hash[:nics_1_mac]
  end


  def nics_1_ip
    @property_hash[:nics_1_ip]
  end
  def nics_1_ip=(value)
    @property_flush[:nics_1_ip] = value
  end


  def nics_1_netmask
    @property_hash[:nics_1_netmask]
  end
  def nics_1_netmask=(value)
    @property_flush[:nics_1_netmask] = value
  end


  def nics_1_gateway
    @property_hash[:nics_1_gateway]
  end
  def nics_1_gateway=(value)
    @property_flush[:nics_1_gateway] = value
  end


  def nics_1_dhcp_server
    @property_hash[:nics_1_dhcp_server]
  end
  def nics_1_dhcp_server=(value)
    @property_flush[:nics_1_dhcp_server] = value
  end

    #.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-

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
