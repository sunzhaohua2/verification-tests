require 'openshift/project_resource'

module BushSlicer
  # represents MachineHealthCheck
  class MachineHealthCheck < ProjectResource
    RESOURCE = 'machinehealthchecks.machine.openshift.io'
  end
end

