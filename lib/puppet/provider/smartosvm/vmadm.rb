Puppet::Type.type(:smartosvm).provide(:vmadm) do
  desc "Provider for vmadm."

  commands :vmadm => 'vmadm'
  commands :shell => 'bash'

#----------------------------------------------------------------------#
# parsers to get parameters and properties 
#----------------------------------------------------------------------#
  
  def self.instances
    vms = vmadm(:list, '-Hp', '-o', 'alias,uuid,quota,max_physical_memory')
    vms.split("\n").collect do |line| aliasname,
                                      uuid ,
                                      quota,
                                      max_physical_memory = line.split(":")
      new(  :aliasname => aliasname,
            :ensure => :present,
            :uuid => uuid,
            :quota => quota,
            :max_physical_memory => max_physical_memory)
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

#----------------------------------------------------------------------#
# parameters - immutable
#----------------------------------------------------------------------#

  def aliasname
    @property_hash[:aliasname]
  end

  def uuid
    @property_hash[:uuid]
  end

#----------------------------------------------------------------------#
# properties - mutable / getter and setters
#----------------------------------------------------------------------#

  def quota
    @property_hash[:quota]
  end

  def quota=(value)
    notice("operating on " + @resource[:aliasname] + " with uuid " + @property_hash[:uuid])
   vmadm(:update, @property_hash[:uuid], 'quota=' + value.to_s)
  end

  def max_physical_memory
    @property_hash[:max_physical_memory]
  end

  def max_physical_memory=(value)
   shell('-c', 'echo \'{"max_physical_memory":"' + value.to_s + '"}\' | vmadm update ' + @property_hash[:uuid])
  end


#----------------------------------------------------------------------#
# create method - very dirty and relies on constucting json as flat
# file and feeding that via /tmp to vmadm 
#----------------------------------------------------------------------#

  def create
    $zonedefjson = '{'
    $zonedefjson += '\"alias\": \"' + @resource[:aliasname] + '\",'
    $zonedefjson += '\"hostname\" : \"' + @resource[:aliasname] + "." + @resource[:dns_domain] +  '\",' 
    $zonedefjson += '\"brand\" : \"' + @resource[:brand] + '\",'
    $zonedefjson += '\"dataset_uuid\" : \"' + @resource[:dataset_uuid] + '\",'
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
