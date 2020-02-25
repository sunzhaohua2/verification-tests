Feature: Machine features testing

  # @author jhou@redhat.com
  # @case_id OCP-21196
  @smoke
  Scenario: Machines should be linked to nodes
    Given I have an IPI deployment
    Then the machines should be linked to nodes

  # @author jhou@redhat.com
  # @case_id OCP-22115
  @smoke
  Scenario: machine-api clusteroperator should be in Available state
    Given evaluation of `cluster_operator('machine-api').condition(type: 'Available')` is stored in the :co_available clipboard
    Then the expression should be true> cb.co_available["status"]=="True"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Degraded')` is stored in the :co_degraded clipboard
    Then the expression should be true> cb.co_degraded["status"]=="False"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Upgradeable')` is stored in the :co_upgradable clipboard
    Then the expression should be true> cb.co_upgradable["status"]=="True"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Progressing')` is stored in the :co_progressing clipboard
    Then the expression should be true> cb.co_progressing["status"]=="False"

  # @author jhou@redhat.com
  # @case_id OCP-25436
  @admin
  @destructive
  Scenario: Scale up and scale down a machineSet
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I pick a random machineset to scale
    And evaluation of `machine_set.available_replicas` is stored in the :replicas_to_restore clipboard

    Given I scale the machineset to +2
    Then the step should succeed
    And I register clean-up steps:
    """
    When I scale the machineset to <%= cb.replicas_to_restore %>
    Then the machineset should have expected number of running machines
    """
    And the machineset should have expected number of running machines

    When I scale the machineset to -1
    Then the step should succeed
    And the machineset should have expected number of running machines


  # @author jhou@redhat.com
  @admin
  Scenario Outline: Metrics is exposed on https
    Given I switch to cluster admin pseudo user
    And I use the "openshift-monitoring" project
    And evaluation of `secret(service_account('prometheus-k8s').get_secret_names.find {|s| s.match('token')}).token` is stored in the :token clipboard

    When I run the :exec admin command with:
      | n                | openshift-monitoring                                           |
      | pod              | prometheus-k8s-0                                               |
      | c                | prometheus                                                     |
      | oc_opts_end      |                                                                |
      | exec_command     | sh                                                             |
      | exec_command_arg | -c                                                             |
      | exec_command_arg | curl -v -s -k -H "Authorization: Bearer <%= cb.token %>" <url> |
    Then the step should succeed

    Examples:
      | url                                                                          |
      | https://machine-api-operator.openshift-machine-api.svc:8443/metrics          | # @case_id OCP-25652
      | https://cluster-autoscaler-operator.openshift-machine-api.svc:9192/metrics   | # @case_id OCP-26111
      | https://machine-approver.openshift-cluster-machine-approver.svc:9192/metrics | # @case_id OCP-26102


  # @author zhsun@redhat.com
  # @case_id OCP-21516
  @admin
  Scenario: Cao listens and deploys cluster-autoscaler based on ClusterAutoscaler resource
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/sunzhaohua2/v3-testfiles/OCP-21516/cloud/cluster-autoscaler.yml |
    Then the step should succeed
    And 1 pods become ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler                                                 |

#   When I run the :get admin command with:
#     | resource          | clusterautoscaler/default    |
#     | show_label        | true                         |
#   Then the output should contain "cluster-autoscaler=default,k8s-app=cluster-autoscaler"

    And I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type       | clusterautoscaler            |
      | object_name_or_id | default                      |
    the step should succeed
    """

  # @author zhsun@redhat.com
  # @case_id OCP-21517
  @admin
  @destructive
  Scenario: CAO listens and annotations machineSets based on MachineAutoscaler resource
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Given I pick a random machineset to scale
 
    When I run oc create over "https://raw.githubusercontent.com/sunzhaohua2/v3-testfiles/OCP-21516/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]                   | <%= machine_set.name %>    |
      | ["spec"]["scaleTargetRef"]["name"]     | <%= machine_set.name %>    |
    Then the step should succeed

    When I run the :get admin command with:
      | resource          | machineautoscaler            |
      | resource_name     | <%= machine_set.name %>      |
      | n                 | openshift-machine-api        |
    Then the step succeeded

    And I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type       | machineautoscaler            |
      | object_name_or_id | <%= machine_set.name %>      |
      | n                 | openshift-machine-api        |
    the step should succeed
    """

  # @author zhsun@redhat.com
  # @case_id OCP-22102
  @admin
  @destructive
  Scenario: Update machineAutoscaler to reference a different MachineSet
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Given I store all machinesets in the "openshift-machine-api" project to the :machinesets clipboard
 
    When I run oc create over "https://raw.githubusercontent.com/sunzhaohua2/v3-testfiles/OCP-21516/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]                   | <%= cb.machinesets[0].machineset_name %>                   |
      | ["spec"]["scaleTargetRef"]["name"]     | <%= cb.machinesets[0].machineset_name %>                   | 
    Then the step should succeed
    
    When I run oc create over "https://raw.githubusercontent.com/sunzhaohua2/v3-testfiles/OCP-21516/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]                   | <%= cb.machinesets[1].machineset_name %>                   |
      | ["spec"]["scaleTargetRef"]["name"]     | <%= cb.machinesets[1].machineset_name %>                   |                  
    Then the step should succeed
                                                                            
    When I run the :patch admin command with:
      | resource          | machineautoscaler                                                               |
      | resource_name     | <%= cb.machinesets[0].machineset_name %>                                        |
      | p                 | {"spec":{"scaleTargetRef":{"name":"<%= cb.machinesets[2].machineset_name %>"}}} |
      | type              | merge                                                                           |
      | n                 | openshift-machine-api                                                           |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource          | machineautoscaler                                                               |
      | name              | <%= cb.machinesets[0].machineset_name %>                                        |
      | n                 |  openshift-machine-api                                                          |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.machinesets[2].machineset_name %>"

    When I run the :describe admin command with:
      | resource          | machineset                                                                      |
      | name              | <%= cb.machinesets[0].machineset_name %>                                        |
      | n                 | openshift-machine-api                                                           |
    Then the step should succeed
    And the output should match "Annotations:\s+<none>"

    When I run the :describe admin command with:
      | resource          | machineset                                                                      |
      | name              | <%= cb.machinesets[2].machineset_name %>                                        |
      | n                 | openshift-machine-api                                                           |
    Then the step should succeed
    And the output should match "Annotations:\s+autoscaling.openshift.io/machineautoscaler: openshift-machine-api/<%= cb.machinesets[0].machineset_name %>"
    When I run the :patch admin command with:
      | resource          | machineautoscaler                                                               |
      | resource_name     | <%= cb.machinesets[0].machineset_name %>                                        |
      | p                 | {"spec":{"scaleTargetRef":{"name":"<%= cb.machinesets[1].machineset_name %>"}}} |
      | type              | merge                                                                           |
      | n                 | openshift-machine-api                                                           |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource          | machineautoscaler                                                               |
      | name              | <%= cb.machinesets[0].machineset_name %>                                        |
      | n                 | openshift-machine-api                                                           |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.machinesets[1].machineset_name %>"

    When I run the :describe admin command with:
      | resource          | machineset                                                                      |
      | name              | <%= cb.machinesets[2].machineset_name %>                                        |
      | n                 | openshift-machine-api                                                           |
    Then the step should succeed
    And the output should match "Annotations:\s+<none>"

    When I run the :describe admin command with:
      | resource          | machineset                                                                      |
      | name              | <%= cb.machinesets[1].machineset_name %>                                        |
      | n                 | openshift-machine-api                                                           |
    Then the step should succeed
    And the output should match "Annotations:\s+autoscaling.openshift.io/machineautoscaler: openshift-machine-api/<%= cb.machinesets[1].machineset_name %>"

    And I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type       | machineautoscaler                                                               |
      | all               |                                                                                 |
      | n                 | openshift-machine-api                                                           |
    the step should succeed
    """
